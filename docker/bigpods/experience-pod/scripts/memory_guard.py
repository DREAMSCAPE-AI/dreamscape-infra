#!/usr/bin/env python3
"""
DreamScape Experience Pod - Memory Guard
DR-328: Monitor and manage memory usage across services
Big Pods Architecture - Memory Management Service
"""

import sys
import os
import time
import logging
import argparse
import psutil
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/supervisor/memory-guard.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('MemoryGuard')

class MemoryGuard:
    def __init__(self, threshold=85, critical_threshold=95, check_interval=60):
        self.threshold = threshold
        self.critical_threshold = critical_threshold
        self.check_interval = check_interval
        self.alert_cooldown = {}
        self.cooldown_period = 300  # 5 minutes
        
    def get_memory_usage(self):
        """Get current memory usage"""
        try:
            memory = psutil.virtual_memory()
            return {
                'total': memory.total,
                'available': memory.available,
                'percent': memory.percent,
                'used': memory.used,
                'free': memory.free
            }
        except Exception as e:
            logger.error(f"Error getting memory usage: {e}")
            return None
    
    def get_process_memory_usage(self, limit=10):
        """Get top memory-consuming processes"""
        try:
            processes = []
            for proc in psutil.process_iter(['pid', 'name', 'memory_percent', 'memory_info']):
                try:
                    proc_info = proc.info
                    processes.append({
                        'pid': proc_info['pid'],
                        'name': proc_info['name'],
                        'memory_percent': proc_info['memory_percent'],
                        'memory_rss': proc_info['memory_info'].rss if proc_info['memory_info'] else 0
                    })
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    pass
            
            # Sort by memory percentage and return top processes
            processes.sort(key=lambda x: x['memory_percent'], reverse=True)
            return processes[:limit]
            
        except Exception as e:
            logger.error(f"Error getting process memory usage: {e}")
            return []
    
    def should_alert(self, alert_type):
        """Check if we should send alert based on cooldown period"""
        current_time = time.time()
        last_alert = self.alert_cooldown.get(alert_type, 0)
        
        if current_time - last_alert > self.cooldown_period:
            self.alert_cooldown[alert_type] = current_time
            return True
        return False
    
    def handle_memory_pressure(self, memory_info, top_processes):
        """Handle memory pressure situations"""
        try:
            if memory_info['percent'] >= self.critical_threshold:
                if self.should_alert('critical'):
                    logger.critical(f"🚨 CRITICAL MEMORY USAGE: {memory_info['percent']:.1f}%")
                    logger.critical(f"Available memory: {memory_info['available'] / (1024**3):.2f}GB")
                    
                    # Log top memory consumers
                    logger.critical("Top memory consumers:")
                    for i, proc in enumerate(top_processes[:5], 1):
                        memory_mb = proc['memory_rss'] / (1024**2)
                        logger.critical(f"  {i}. {proc['name']} (PID {proc['pid']}): "
                                      f"{proc['memory_percent']:.1f}% ({memory_mb:.1f}MB)")
                    
                    # Here you could implement memory recovery actions:
                    # - Kill non-essential processes
                    # - Clear caches
                    # - Restart services
                    
            elif memory_info['percent'] >= self.threshold:
                if self.should_alert('warning'):
                    logger.warning(f"⚠️ High memory usage: {memory_info['percent']:.1f}%")
                    logger.warning(f"Available memory: {memory_info['available'] / (1024**3):.2f}GB")
                    
        except Exception as e:
            logger.error(f"Error handling memory pressure: {e}")
    
    def run_memory_check(self):
        """Run single memory check cycle"""
        try:
            # Get memory usage
            memory_info = self.get_memory_usage()
            if not memory_info:
                return
            
            # Get top processes
            top_processes = self.get_process_memory_usage()
            
            # Log basic info
            logger.info(f"💾 Memory usage: {memory_info['percent']:.1f}% "
                       f"({memory_info['used'] / (1024**3):.2f}GB / "
                       f"{memory_info['total'] / (1024**3):.2f}GB)")
            
            # Handle memory pressure
            self.handle_memory_pressure(memory_info, top_processes)
            
        except Exception as e:
            logger.error(f"Error during memory check: {e}")
    
    def run_continuous_monitoring(self):
        """Run continuous memory monitoring"""
        logger.info(f"💾 Memory Guard started - Threshold: {self.threshold}%, "
                   f"Critical: {self.critical_threshold}%")
        
        while True:
            try:
                self.run_memory_check()
                time.sleep(self.check_interval)
                
            except KeyboardInterrupt:
                logger.info("Memory Guard stopping...")
                break
            except Exception as e:
                logger.error(f"Unexpected error in monitoring loop: {e}")
                time.sleep(5)

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='DreamScape Memory Guard')
    parser.add_argument('--threshold', type=int, default=85, 
                       help='Memory usage warning threshold (default: 85%%)')
    parser.add_argument('--critical', type=int, default=95,
                       help='Memory usage critical threshold (default: 95%%)')
    parser.add_argument('--interval', type=int, default=60,
                       help='Check interval in seconds (default: 60)')
    
    args = parser.parse_args()
    
    try:
        guard = MemoryGuard(
            threshold=args.threshold,
            critical_threshold=args.critical,
            check_interval=args.interval
        )
        guard.run_continuous_monitoring()
        
    except Exception as e:
        logger.error(f"Memory Guard failed to start: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()