#!/usr/bin/env python3
"""
DreamScape Experience Pod - Performance Monitor
DR-328: Monitor system performance and resource usage
Big Pods Architecture - Performance Tracking Service
"""

import sys
import os
import json
import time
import psutil
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/supervisor/performance-monitor.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('PerformanceMonitor')

def collect_system_metrics():
    """Collect system performance metrics"""
    try:
        # CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        cpu_count = psutil.cpu_count()
        
        # Memory usage
        memory = psutil.virtual_memory()
        
        # Disk usage
        disk = psutil.disk_usage('/')
        
        # Network stats
        network = psutil.net_io_counters()
        
        # Process count
        process_count = len(psutil.pids())
        
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'cpu': {
                'percent': cpu_percent,
                'count': cpu_count,
                'load_avg': os.getloadavg() if hasattr(os, 'getloadavg') else [0, 0, 0]
            },
            'memory': {
                'total': memory.total,
                'available': memory.available,
                'percent': memory.percent,
                'used': memory.used,
                'free': memory.free
            },
            'disk': {
                'total': disk.total,
                'used': disk.used,
                'free': disk.free,
                'percent': (disk.used / disk.total) * 100
            },
            'network': {
                'bytes_sent': network.bytes_sent,
                'bytes_recv': network.bytes_recv,
                'packets_sent': network.packets_sent,
                'packets_recv': network.packets_recv
            },
            'processes': {
                'count': process_count
            }
        }
        
        return metrics
        
    except Exception as e:
        logger.error(f"Error collecting system metrics: {e}")
        return None

def check_performance_thresholds(metrics):
    """Check if metrics exceed performance thresholds"""
    alerts = []
    
    # CPU threshold (80%)
    if metrics['cpu']['percent'] > 80:
        alerts.append({
            'type': 'cpu_high',
            'message': f"High CPU usage: {metrics['cpu']['percent']:.1f}%",
            'severity': 'warning' if metrics['cpu']['percent'] < 90 else 'critical'
        })
    
    # Memory threshold (85%)
    if metrics['memory']['percent'] > 85:
        alerts.append({
            'type': 'memory_high',
            'message': f"High memory usage: {metrics['memory']['percent']:.1f}%",
            'severity': 'warning' if metrics['memory']['percent'] < 95 else 'critical'
        })
    
    # Disk threshold (90%)
    if metrics['disk']['percent'] > 90:
        alerts.append({
            'type': 'disk_high',
            'message': f"High disk usage: {metrics['disk']['percent']:.1f}%",
            'severity': 'warning' if metrics['disk']['percent'] < 95 else 'critical'
        })
    
    return alerts

def process_tick_event():
    """Process TICK_60 events from supervisor"""
    try:
        # Read event headers
        headers = {}
        while True:
            line = sys.stdin.readline().strip()
            if not line:
                break
            if ':' in line:
                key, value = line.split(':', 1)
                headers[key] = value.strip()
        
        # Read event payload
        payload_len = int(headers.get('len', '0'))
        if payload_len > 0:
            payload = sys.stdin.read(payload_len)
        
        # Collect performance metrics
        metrics = collect_system_metrics()
        if metrics:
            # Log basic metrics
            logger.info(f"📊 CPU: {metrics['cpu']['percent']:.1f}% | "
                       f"Memory: {metrics['memory']['percent']:.1f}% | "
                       f"Disk: {metrics['disk']['percent']:.1f}% | "
                       f"Processes: {metrics['processes']['count']}")
            
            # Check thresholds and generate alerts
            alerts = check_performance_thresholds(metrics)
            for alert in alerts:
                if alert['severity'] == 'critical':
                    logger.error(f"🚨 {alert['message']}")
                else:
                    logger.warning(f"⚠️ {alert['message']}")
        
        # Send OK response to supervisor
        sys.stdout.write('RESULT 2\nOK')
        sys.stdout.flush()
        
    except Exception as e:
        logger.error(f"Error processing performance monitoring event: {e}")
        sys.stdout.write('RESULT 2\nFAIL')
        sys.stdout.flush()

def main():
    """Main event processing loop"""
    logger.info("📊 Experience Pod Performance Monitor started")
    
    # Send READY to supervisor
    sys.stdout.write('READY\n')
    sys.stdout.flush()
    
    while True:
        try:
            process_tick_event()
        except KeyboardInterrupt:
            logger.info("Performance Monitor stopping...")
            break
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()