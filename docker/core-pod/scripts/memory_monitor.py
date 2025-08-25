#!/usr/bin/env python3
"""
Memory Monitor for DreamScape Core Pod
DR-336: INFRA-010.3 - Monitors memory usage and prevents OOM conditions
"""

import sys
import json
import psutil
import logging
import subprocess
from datetime import datetime
from supervisor import childutils

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('memory-monitor')

class MemoryMonitor:
    """Monitors system and process memory usage"""
    
    def __init__(self):
        self.memory_threshold = 85.0  # percent
        self.critical_threshold = 95.0  # percent
        self.process_threshold = 200  # MB per process
        self.monitored_processes = ['auth-service', 'user-service', 'nginx']
        self.memory_history = []
        self.max_history = 60  # Keep 1 hour of data (60 minutes)
        
    def get_system_memory(self):
        """Get system memory statistics"""
        memory = psutil.virtual_memory()
        swap = psutil.swap_memory()
        
        return {
            'total_mb': round(memory.total / 1024 / 1024, 2),
            'available_mb': round(memory.available / 1024 / 1024, 2),
            'used_mb': round(memory.used / 1024 / 1024, 2),
            'percent': memory.percent,
            'swap_total_mb': round(swap.total / 1024 / 1024, 2),
            'swap_used_mb': round(swap.used / 1024 / 1024, 2),
            'swap_percent': swap.percent
        }
    
    def get_process_memory(self, process_name):
        """Get memory usage for a specific process"""
        try:
            # Find process by name
            for proc in psutil.process_iter(['pid', 'name', 'memory_info', 'cmdline']):
                try:
                    if process_name in ' '.join(proc.info['cmdline'] or []):
                        memory_info = proc.info['memory_info']
                        return {
                            'pid': proc.info['pid'],
                            'name': process_name,
                            'rss_mb': round(memory_info.rss / 1024 / 1024, 2),
                            'vms_mb': round(memory_info.vms / 1024 / 1024, 2),
                            'percent': proc.memory_percent()
                        }
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
        except Exception as e:
            logger.error(f"Error getting memory for {process_name}: {e}")
        
        return None
    
    def get_all_process_memory(self):
        """Get memory usage for all monitored processes"""
        processes = []
        
        for process_name in self.monitored_processes:
            proc_memory = self.get_process_memory(process_name)
            if proc_memory:
                processes.append(proc_memory)
        
        return processes
    
    def check_memory_thresholds(self, system_memory, process_memory):
        """Check if memory usage exceeds thresholds"""
        alerts = []
        
        # Check system memory
        if system_memory['percent'] >= self.critical_threshold:
            alerts.append({
                'type': 'system_memory_critical',
                'message': f"System memory usage critical: {system_memory['percent']:.1f}%",
                'severity': 'critical',
                'value': system_memory['percent']
            })
        elif system_memory['percent'] >= self.memory_threshold:
            alerts.append({
                'type': 'system_memory_warning',
                'message': f"System memory usage high: {system_memory['percent']:.1f}%",
                'severity': 'warning',
                'value': system_memory['percent']
            })
        
        # Check swap usage
        if system_memory['swap_percent'] > 50:
            alerts.append({
                'type': 'swap_usage_high',
                'message': f"Swap usage high: {system_memory['swap_percent']:.1f}%",
                'severity': 'warning',
                'value': system_memory['swap_percent']
            })
        
        # Check individual processes
        for proc in process_memory:
            if proc['rss_mb'] > self.process_threshold:
                alerts.append({
                    'type': 'process_memory_high',
                    'message': f"Process {proc['name']} memory usage high: {proc['rss_mb']:.1f}MB",
                    'severity': 'warning',
                    'process': proc['name'],
                    'pid': proc['pid'],
                    'value': proc['rss_mb']
                })
        
        return alerts
    
    def handle_memory_alerts(self, alerts):
        """Handle memory threshold alerts"""
        for alert in alerts:
            if alert['severity'] == 'critical':
                logger.critical(alert['message'])
                self.handle_critical_memory(alert)
            else:
                logger.warning(alert['message'])
            
            # Save alert to file
            self.save_alert(alert)
    
    def handle_critical_memory(self, alert):
        """Handle critical memory conditions"""
        if alert['type'] == 'system_memory_critical':
            logger.critical("System memory critical - attempting to free memory")
            
            # Try to restart memory-heavy processes
            try:
                # Restart user-service first (typically uses more memory)
                subprocess.run(['supervisorctl', 'restart', 'user-service'], timeout=30)
                logger.info("Restarted user-service due to critical memory condition")
            except Exception as e:
                logger.error(f"Failed to restart user-service: {e}")
    
    def save_alert(self, alert):
        """Save memory alert to file"""
        try:
            alert_with_timestamp = {
                **alert,
                'timestamp': datetime.utcnow().isoformat(),
                'source': 'memory-monitor'
            }
            
            with open('/tmp/memory_alerts.json', 'a') as f:
                f.write(json.dumps(alert_with_timestamp) + '\n')
        except Exception as e:
            logger.error(f"Error saving memory alert: {e}")
    
    def save_memory_metrics(self, system_memory, process_memory):
        """Save memory metrics for monitoring"""
        metrics = {
            'timestamp': datetime.utcnow().isoformat(),
            'system': system_memory,
            'processes': process_memory
        }
        
        # Add to history
        self.memory_history.append(metrics)
        
        # Keep only recent history
        if len(self.memory_history) > self.max_history:
            self.memory_history = self.memory_history[-self.max_history:]
        
        # Save current metrics
        try:
            with open('/tmp/memory_metrics.json', 'w') as f:
                json.dump({
                    'current': metrics,
                    'history': self.memory_history[-10:]  # Last 10 measurements
                }, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving memory metrics: {e}")
    
    def run(self):
        """Main monitoring loop triggered by Supervisor TICK events"""
        logger.info("Starting DreamScape Memory Monitor")
        
        while True:
            try:
                # Wait for TICK_60 event from supervisor
                headers, payload = childutils.listener.wait()
                
                # Get memory statistics
                system_memory = self.get_system_memory()
                process_memory = self.get_all_process_memory()
                
                # Check thresholds
                alerts = self.check_memory_thresholds(system_memory, process_memory)
                
                # Handle alerts
                if alerts:
                    self.handle_memory_alerts(alerts)
                
                # Save metrics
                self.save_memory_metrics(system_memory, process_memory)
                
                # Log current status
                logger.info(f"Memory: {system_memory['percent']:.1f}% "
                           f"({system_memory['used_mb']:.0f}MB/"
                           f"{system_memory['total_mb']:.0f}MB)")
                
                # Acknowledge the event
                childutils.listener.ok()
                
            except KeyboardInterrupt:
                logger.info("Memory monitor stopped by user")
                break
            except Exception as e:
                logger.error(f"Unexpected error in memory monitor: {e}")
                try:
                    childutils.listener.fail()
                except:
                    pass


if __name__ == '__main__':
    monitor = MemoryMonitor()
    monitor.run()