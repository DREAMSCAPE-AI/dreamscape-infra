#!/usr/bin/env python3
"""
Health Monitor for DreamScape Core Pod
DR-336: INFRA-010.3 - Monitors all services and provides aggregated health status
"""

import time
import json
import logging
import subprocess
import urllib.request
import urllib.error
from datetime import datetime
from typing import Dict, List, Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('health-monitor')

class HealthMonitor:
    """Monitors health of all services in the Core Pod"""
    
    def __init__(self):
        self.services = {
            'auth-service': {
                'url': 'http://localhost:3001/health',
                'timeout': 5,
                'required': True
            },
            'user-service': {
                'url': 'http://localhost:3002/health',
                'timeout': 5,
                'required': True
            },
            'nginx': {
                'url': 'http://localhost:80/health',
                'timeout': 3,
                'required': True
            }
        }
        self.status_file = '/tmp/core_pod_health.json'
        self.check_interval = 30  # seconds
        
    def check_service_health(self, service_name: str, config: Dict[str, Any]) -> Dict[str, Any]:
        """Check health of a single service"""
        start_time = time.time()
        
        try:
            request = urllib.request.Request(
                config['url'],
                headers={'User-Agent': 'CorePod-HealthMonitor/1.0'}
            )
            
            with urllib.request.urlopen(request, timeout=config['timeout']) as response:
                response_time = (time.time() - start_time) * 1000  # ms
                
                if response.status == 200:
                    try:
                        body = response.read().decode('utf-8')
                        return {
                            'name': service_name,
                            'status': 'healthy',
                            'response_time_ms': round(response_time, 2),
                            'response_body': body,
                            'timestamp': datetime.utcnow().isoformat(),
                            'error': None
                        }
                    except Exception as e:
                        return {
                            'name': service_name,
                            'status': 'healthy',
                            'response_time_ms': round(response_time, 2),
                            'response_body': 'OK',
                            'timestamp': datetime.utcnow().isoformat(),
                            'error': None
                        }
                else:
                    return {
                        'name': service_name,
                        'status': 'unhealthy',
                        'response_time_ms': round(response_time, 2),
                        'response_body': None,
                        'timestamp': datetime.utcnow().isoformat(),
                        'error': f'HTTP {response.status}'
                    }
                    
        except urllib.error.URLError as e:
            response_time = (time.time() - start_time) * 1000
            return {
                'name': service_name,
                'status': 'unhealthy',
                'response_time_ms': round(response_time, 2),
                'response_body': None,
                'timestamp': datetime.utcnow().isoformat(),
                'error': str(e)
            }
        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            return {
                'name': service_name,
                'status': 'error',
                'response_time_ms': round(response_time, 2),
                'response_body': None,
                'timestamp': datetime.utcnow().isoformat(),
                'error': str(e)
            }
    
    def get_supervisor_status(self) -> List[Dict[str, Any]]:
        """Get status of all Supervisor programs"""
        try:
            result = subprocess.run(
                ['supervisorctl', 'status'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            programs = []
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 2:
                            programs.append({
                                'name': parts[0],
                                'status': parts[1],
                                'description': ' '.join(parts[2:]) if len(parts) > 2 else ''
                            })
            
            return programs
            
        except subprocess.TimeoutExpired:
            logger.error("Supervisor status check timed out")
            return []
        except Exception as e:
            logger.error(f"Error getting supervisor status: {e}")
            return []
    
    def check_all_services(self) -> Dict[str, Any]:
        """Check health of all services and return aggregated status"""
        service_results = []
        
        # Check HTTP endpoints
        for service_name, config in self.services.items():
            result = self.check_service_health(service_name, config)
            service_results.append(result)
            
            status_emoji = "✅" if result['status'] == 'healthy' else "❌"
            logger.info(f"{status_emoji} {service_name}: {result['status']} ({result['response_time_ms']}ms)")
        
        # Get Supervisor program status
        supervisor_status = self.get_supervisor_status()
        
        # Determine overall health
        healthy_count = sum(1 for r in service_results if r['status'] == 'healthy')
        total_required = sum(1 for config in self.services.values() if config['required'])
        
        overall_status = 'healthy' if healthy_count == total_required else 'degraded'
        
        # Calculate average response time
        response_times = [r['response_time_ms'] for r in service_results if r['response_time_ms'] > 0]
        avg_response_time = sum(response_times) / len(response_times) if response_times else 0
        
        health_report = {
            'overall_status': overall_status,
            'timestamp': datetime.utcnow().isoformat(),
            'services': service_results,
            'supervisor_programs': supervisor_status,
            'summary': {
                'total_services': len(service_results),
                'healthy_services': healthy_count,
                'unhealthy_services': len(service_results) - healthy_count,
                'average_response_time_ms': round(avg_response_time, 2)
            }
        }
        
        return health_report
    
    def save_health_status(self, health_report: Dict[str, Any]):
        """Save health status to file for external access"""
        try:
            with open(self.status_file, 'w') as f:
                json.dump(health_report, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving health status: {e}")
    
    def restart_unhealthy_services(self, health_report: Dict[str, Any]):
        """Restart services that are unhealthy"""
        for service in health_report['services']:
            if service['status'] in ['unhealthy', 'error'] and service['name'] in ['auth-service', 'user-service']:
                logger.warning(f"Attempting to restart unhealthy service: {service['name']}")
                try:
                    subprocess.run(
                        ['supervisorctl', 'restart', service['name']],
                        timeout=30,
                        check=True
                    )
                    logger.info(f"Successfully restarted {service['name']}")
                except subprocess.CalledProcessError as e:
                    logger.error(f"Failed to restart {service['name']}: {e}")
                except subprocess.TimeoutExpired:
                    logger.error(f"Timeout restarting {service['name']}")
    
    def run(self):
        """Main monitoring loop"""
        logger.info("Starting DreamScape Core Pod Health Monitor")
        logger.info(f"Monitoring {len(self.services)} services every {self.check_interval} seconds")
        
        while True:
            try:
                health_report = self.check_all_services()
                self.save_health_status(health_report)
                
                # Log overall status
                status_emoji = "🟢" if health_report['overall_status'] == 'healthy' else "🟡"
                logger.info(f"{status_emoji} Overall status: {health_report['overall_status']} "
                           f"({health_report['summary']['healthy_services']}/{health_report['summary']['total_services']} healthy)")
                
                # Restart unhealthy services if needed
                if health_report['overall_status'] != 'healthy':
                    self.restart_unhealthy_services(health_report)
                
                time.sleep(self.check_interval)
                
            except KeyboardInterrupt:
                logger.info("Health monitor stopped by user")
                break
            except Exception as e:
                logger.error(f"Unexpected error in health monitor: {e}")
                time.sleep(5)  # Short sleep before retry


if __name__ == '__main__':
    monitor = HealthMonitor()
    monitor.run()