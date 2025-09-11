#!/usr/bin/env python3
"""
DreamScape Experience Pod - Health Monitor
Comprehensive monitoring for Frontend + VR + Gateway services
Big Pods Architecture - Health & Performance Monitoring
"""

import os
import sys
import time
import json
import logging
import requests
import psutil
from pathlib import Path
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/supervisor/health-monitor.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('ExperienceHealthMonitor')

@dataclass
class ServiceEndpoint:
    """Service endpoint configuration"""
    name: str
    url: str
    timeout: int = 5
    expected_status: int = 200
    critical: bool = True

@dataclass
class HealthMetrics:
    """Health metrics data structure"""
    timestamp: int
    cpu_usage: float
    memory_usage: float
    disk_usage: float
    network_io: Dict[str, int]
    service_status: Dict[str, bool]
    performance_metrics: Dict[str, float]
    vr_content_stats: Dict[str, int]

class ExperienceHealthMonitor:
    """
    Comprehensive health monitoring for Experience Pod
    Monitors NGINX, Panorama Service, Gateway, system resources, and VR content performance
    """
    
    def __init__(self):
        self.monitor_interval = int(os.getenv('MONITOR_INTERVAL', '30'))
        self.alert_thresholds = self._parse_alert_thresholds()
        self.health_status_file = '/tmp/health/experience-pod-status.json'
        self.vr_content_path = os.getenv('VR_CONTENT_PATH', '/usr/share/nginx/html/vr')
        self.nginx_cache_path = os.getenv('VR_CACHE_PATH', '/var/cache/nginx/vr')
        
        # Service endpoints to monitor
        self.service_endpoints = [
            ServiceEndpoint("nginx", "http://localhost:80/health", timeout=5, critical=True),
            ServiceEndpoint("panorama-service", "http://localhost:3006/health", timeout=10, critical=True),
            ServiceEndpoint("gateway-service", "http://localhost:3007/health", timeout=10, critical=True),
            ServiceEndpoint("nginx-status", "http://localhost:80/nginx-status", timeout=5, critical=False)
        ]
        
        # Create health status directory
        Path(self.health_status_file).parent.mkdir(parents=True, exist_ok=True)
        
        logger.info(f"Experience Pod Health Monitor initialized - Interval: {self.monitor_interval}s")

    def _parse_alert_thresholds(self) -> Dict[str, float]:
        """Parse alert thresholds from environment"""
        default_thresholds = {
            'cpu': 80.0,
            'memory': 85.0,
            'disk': 90.0,
            'response_time': 2.0,
            'error_rate': 5.0
        }
        
        threshold_env = os.getenv('ALERT_THRESHOLDS', '')
        if not threshold_env:
            return default_thresholds
            
        try:
            # Parse format: "cpu:80,memory:85,disk:90"
            for threshold_pair in threshold_env.split(','):
                key, value = threshold_pair.split(':')
                default_thresholds[key.strip()] = float(value.strip())
            return default_thresholds
        except Exception as e:
            logger.warning(f"Failed to parse alert thresholds: {e}, using defaults")
            return default_thresholds

    def get_system_metrics(self) -> Tuple[float, float, float, Dict[str, int]]:
        """Get system resource metrics"""
        try:
            # CPU usage
            cpu_usage = psutil.cpu_percent(interval=1)
            
            # Memory usage
            memory = psutil.virtual_memory()
            memory_usage = memory.percent
            
            # Disk usage for VR content
            vr_disk = psutil.disk_usage(self.vr_content_path)
            disk_usage = vr_disk.percent
            
            # Network I/O
            network = psutil.net_io_counters()
            network_io = {
                'bytes_sent': network.bytes_sent,
                'bytes_recv': network.bytes_recv,
                'packets_sent': network.packets_sent,
                'packets_recv': network.packets_recv
            }
            
            return cpu_usage, memory_usage, disk_usage, network_io
            
        except Exception as e:
            logger.error(f"Failed to get system metrics: {e}")
            return 0.0, 0.0, 0.0, {}

    def check_service_health(self, endpoint: ServiceEndpoint) -> Tuple[bool, float]:
        """Check health of a service endpoint"""
        try:
            start_time = time.time()
            response = requests.get(endpoint.url, timeout=endpoint.timeout)
            response_time = time.time() - start_time
            
            is_healthy = response.status_code == endpoint.expected_status
            
            if not is_healthy:
                logger.warning(f"Service {endpoint.name} unhealthy: HTTP {response.status_code}")
            
            return is_healthy, response_time
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Service {endpoint.name} check failed: {e}")
            return False, 0.0
        except Exception as e:
            logger.error(f"Unexpected error checking {endpoint.name}: {e}")
            return False, 0.0

    def get_nginx_metrics(self) -> Dict[str, float]:
        """Get NGINX performance metrics"""
        try:
            response = requests.get("http://localhost:80/nginx-status", timeout=5)
            if response.status_code != 200:
                return {}
            
            # Parse nginx status output
            lines = response.text.strip().split('\n')
            metrics = {}
            
            for line in lines:
                if 'Active connections' in line:
                    metrics['active_connections'] = float(line.split(':')[1].strip())
                elif line.strip() and line[0].isdigit():
                    # Server accepts handled requests line
                    parts = line.strip().split()
                    if len(parts) >= 3:
                        metrics['accepts'] = float(parts[0])
                        metrics['handled'] = float(parts[1])
                        metrics['requests'] = float(parts[2])
                        if metrics['handled'] > 0:
                            metrics['request_rate'] = metrics['requests'] / metrics['handled']
            
            return metrics
            
        except Exception as e:
            logger.error(f"Failed to get NGINX metrics: {e}")
            return {}

    def get_vr_content_stats(self) -> Dict[str, int]:
        """Get VR content statistics"""
        try:
            stats = {
                'total_vr_files': 0,
                'total_vr_size': 0,
                'optimized_variants': 0,
                'cache_files': 0,
                'cache_size': 0,
                'thumbnails': 0
            }
            
            # Count original VR files
            vr_path = Path(self.vr_content_path)
            if vr_path.exists():
                for ext in ['.jpg', '.jpeg', '.png', '.webp', '.avif']:
                    vr_files = list(vr_path.glob(f"**/*{ext}"))
                    stats['total_vr_files'] += len(vr_files)
                    stats['total_vr_size'] += sum(f.stat().st_size for f in vr_files if f.exists())
            
            # Count optimized cache files
            cache_path = Path(self.nginx_cache_path)
            if cache_path.exists():
                for quality_dir in ['hq', 'mq', 'lq']:
                    quality_path = cache_path / quality_dir
                    if quality_path.exists():
                        cache_files = list(quality_path.glob("*"))
                        stats['optimized_variants'] += len(cache_files)
                        stats['cache_size'] += sum(f.stat().st_size for f in cache_files if f.is_file())
                
                # Count thumbnails
                thumb_path = cache_path / 'thumbs'
                if thumb_path.exists():
                    thumbs = list(thumb_path.glob("*.jpg"))
                    stats['thumbnails'] = len(thumbs)
                
                # Total cache files
                all_cache_files = list(cache_path.glob("**/*"))
                stats['cache_files'] = len([f for f in all_cache_files if f.is_file()])
            
            return stats
            
        except Exception as e:
            logger.error(f"Failed to get VR content stats: {e}")
            return {}

    def get_performance_metrics(self) -> Dict[str, float]:
        """Get performance-specific metrics"""
        try:
            metrics = {}
            
            # Get NGINX metrics
            nginx_metrics = self.get_nginx_metrics()
            metrics.update(nginx_metrics)
            
            # Check response times for critical endpoints
            critical_endpoints = [ep for ep in self.service_endpoints if ep.critical]
            response_times = []
            
            for endpoint in critical_endpoints:
                is_healthy, response_time = self.check_service_health(endpoint)
                metrics[f"{endpoint.name}_response_time"] = response_time
                if response_time > 0:
                    response_times.append(response_time)
            
            # Average response time
            if response_times:
                metrics['avg_response_time'] = sum(response_times) / len(response_times)
                metrics['max_response_time'] = max(response_times)
            
            return metrics
            
        except Exception as e:
            logger.error(f"Failed to get performance metrics: {e}")
            return {}

    def check_alert_conditions(self, metrics: HealthMetrics) -> List[str]:
        """Check for alert conditions"""
        alerts = []
        
        # System resource alerts
        if metrics.cpu_usage > self.alert_thresholds['cpu']:
            alerts.append(f"High CPU usage: {metrics.cpu_usage:.1f}%")
        
        if metrics.memory_usage > self.alert_thresholds['memory']:
            alerts.append(f"High memory usage: {metrics.memory_usage:.1f}%")
        
        if metrics.disk_usage > self.alert_thresholds['disk']:
            alerts.append(f"High disk usage: {metrics.disk_usage:.1f}%")
        
        # Service availability alerts
        critical_services_down = [name for name, status in metrics.service_status.items() 
                                if not status and any(ep.name == name and ep.critical for ep in self.service_endpoints)]
        
        if critical_services_down:
            alerts.append(f"Critical services down: {', '.join(critical_services_down)}")
        
        # Performance alerts
        avg_response_time = metrics.performance_metrics.get('avg_response_time', 0)
        if avg_response_time > self.alert_thresholds['response_time']:
            alerts.append(f"High response time: {avg_response_time:.2f}s")
        
        return alerts

    def save_health_status(self, metrics: HealthMetrics, alerts: List[str]):
        """Save health status to file for external monitoring"""
        try:
            status_data = {
                'timestamp': metrics.timestamp,
                'status': 'healthy' if not alerts else 'warning',
                'alerts': alerts,
                'metrics': {
                    'system': {
                        'cpu_usage': metrics.cpu_usage,
                        'memory_usage': metrics.memory_usage,
                        'disk_usage': metrics.disk_usage
                    },
                    'services': metrics.service_status,
                    'performance': metrics.performance_metrics,
                    'vr_content': metrics.vr_content_stats
                }
            }
            
            with open(self.health_status_file, 'w') as f:
                json.dump(status_data, f, indent=2)
            
        except Exception as e:
            logger.error(f"Failed to save health status: {e}")

    def run_health_check(self) -> HealthMetrics:
        """Run comprehensive health check"""
        try:
            timestamp = int(time.time())
            
            # Get system metrics
            cpu_usage, memory_usage, disk_usage, network_io = self.get_system_metrics()
            
            # Check all service endpoints
            service_status = {}
            for endpoint in self.service_endpoints:
                is_healthy, response_time = self.check_service_health(endpoint)
                service_status[endpoint.name] = is_healthy
            
            # Get performance metrics
            performance_metrics = self.get_performance_metrics()
            
            # Get VR content stats
            vr_content_stats = self.get_vr_content_stats()
            
            return HealthMetrics(
                timestamp=timestamp,
                cpu_usage=cpu_usage,
                memory_usage=memory_usage,
                disk_usage=disk_usage,
                network_io=network_io,
                service_status=service_status,
                performance_metrics=performance_metrics,
                vr_content_stats=vr_content_stats
            )
            
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return HealthMetrics(
                timestamp=int(time.time()),
                cpu_usage=0, memory_usage=0, disk_usage=0,
                network_io={}, service_status={}, performance_metrics={}, vr_content_stats={}
            )

    def run_monitoring_loop(self):
        """Main monitoring loop"""
        logger.info("Starting Experience Pod Health Monitor...")
        
        while True:
            try:
                # Run health check
                metrics = self.run_health_check()
                
                # Check for alerts
                alerts = self.check_alert_conditions(metrics)
                
                # Log health status
                if alerts:
                    logger.warning(f"Health check alerts: {'; '.join(alerts)}")
                else:
                    logger.info(f"Health check OK - CPU: {metrics.cpu_usage:.1f}%, "
                              f"Memory: {metrics.memory_usage:.1f}%, "
                              f"Services: {sum(metrics.service_status.values())}/{len(metrics.service_status)} up")
                
                # Log VR content stats periodically
                if metrics.vr_content_stats:
                    logger.info(f"VR Content - Files: {metrics.vr_content_stats.get('total_vr_files', 0)}, "
                              f"Cache variants: {metrics.vr_content_stats.get('optimized_variants', 0)}, "
                              f"Thumbnails: {metrics.vr_content_stats.get('thumbnails', 0)}")
                
                # Save status for external monitoring
                self.save_health_status(metrics, alerts)
                
                # Wait for next check
                time.sleep(self.monitor_interval)
                
            except KeyboardInterrupt:
                logger.info("Health monitor stopping...")
                break
            except Exception as e:
                logger.error(f"Monitoring loop error: {e}")
                time.sleep(60)  # Wait before retrying

def main():
    """Main entry point"""
    try:
        monitor = ExperienceHealthMonitor()
        monitor.run_monitoring_loop()
    except Exception as e:
        logger.error(f"Experience Health Monitor failed to start: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()