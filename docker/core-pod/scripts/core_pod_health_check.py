#!/usr/bin/env python3
"""
Core Pod Health Check for Docker
DR-336: INFRA-010.3 - Validates health of all services in the Core Pod
"""

import sys
import json
import urllib.request
import urllib.error
import subprocess
import time
from datetime import datetime

class CorePodHealthCheck:
    """Comprehensive health check for the Core Pod"""
    
    def __init__(self):
        self.services = [
            {
                'name': 'auth-service',
                'url': 'http://localhost:3001/health',
                'timeout': 5,
                'critical': True
            },
            {
                'name': 'user-service', 
                'url': 'http://localhost:3002/health',
                'timeout': 5,
                'critical': True
            },
            {
                'name': 'nginx',
                'url': 'http://localhost:80/health',
                'timeout': 3,
                'critical': True
            }
        ]
        
        self.supervisor_programs = [
            'auth-service',
            'user-service', 
            'nginx',
            'health-checker'
        ]
    
    def check_http_endpoint(self, service):
        """Check if an HTTP endpoint is healthy"""
        try:
            request = urllib.request.Request(
                service['url'],
                headers={'User-Agent': 'CorePod-HealthCheck/1.0'}
            )
            
            start_time = time.time()
            with urllib.request.urlopen(request, timeout=service['timeout']) as response:
                response_time = (time.time() - start_time) * 1000
                
                if response.status == 200:
                    return {
                        'healthy': True,
                        'response_time_ms': round(response_time, 2),
                        'status_code': response.status,
                        'error': None
                    }
                else:
                    return {
                        'healthy': False,
                        'response_time_ms': round(response_time, 2),
                        'status_code': response.status,
                        'error': f'HTTP {response.status}'
                    }
                    
        except urllib.error.URLError as e:
            return {
                'healthy': False,
                'response_time_ms': None,
                'status_code': None,
                'error': f'URLError: {str(e)}'
            }
        except Exception as e:
            return {
                'healthy': False,
                'response_time_ms': None,
                'status_code': None,
                'error': f'Exception: {str(e)}'
            }
    
    def check_supervisor_programs(self):
        """Check status of Supervisor programs"""
        try:
            result = subprocess.run(
                ['supervisorctl', 'status'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                return {
                    'healthy': False,
                    'error': f'supervisorctl failed: {result.stderr}'
                }
            
            # Parse supervisor status output
            programs = {}
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    parts = line.split()
                    if len(parts) >= 2:
                        program_name = parts[0]
                        status = parts[1]
                        programs[program_name] = {
                            'status': status,
                            'running': status == 'RUNNING',
                            'description': ' '.join(parts[2:]) if len(parts) > 2 else ''
                        }
            
            # Check critical programs
            unhealthy_programs = []
            for program in self.supervisor_programs:
                if program not in programs:
                    unhealthy_programs.append(f'{program}: NOT_FOUND')
                elif not programs[program]['running']:
                    unhealthy_programs.append(f'{program}: {programs[program]["status"]}')
            
            return {
                'healthy': len(unhealthy_programs) == 0,
                'programs': programs,
                'unhealthy_programs': unhealthy_programs,
                'error': None if len(unhealthy_programs) == 0 else f'Unhealthy programs: {", ".join(unhealthy_programs)}'
            }
            
        except subprocess.TimeoutExpired:
            return {
                'healthy': False,
                'error': 'supervisorctl timeout'
            }
        except Exception as e:
            return {
                'healthy': False,
                'error': f'supervisor check failed: {str(e)}'
            }
    
    def check_disk_space(self):
        """Check available disk space"""
        try:
            result = subprocess.run(
                ['df', '-h', '/'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) >= 2:
                    parts = lines[1].split()
                    if len(parts) >= 5:
                        used_percent = parts[4].rstrip('%')
                        try:
                            used_percent_int = int(used_percent)
                            return {
                                'healthy': used_percent_int < 90,  # Fail if >90% used
                                'used_percent': used_percent_int,
                                'available': parts[3],
                                'error': None if used_percent_int < 90 else f'Disk usage high: {used_percent}%'
                            }
                        except ValueError:
                            pass
            
            return {
                'healthy': False,
                'error': 'Could not parse disk usage'
            }
            
        except Exception as e:
            return {
                'healthy': False,
                'error': f'disk check failed: {str(e)}'
            }
    
    def run_health_check(self):
        """Run comprehensive health check"""
        start_time = time.time()
        
        health_report = {
            'timestamp': datetime.utcnow().isoformat(),
            'overall_healthy': True,
            'check_duration_ms': 0,
            'services': {},
            'supervisor': {},
            'system': {}
        }
        
        # Check HTTP services
        print("Checking HTTP services...", file=sys.stderr)
        for service in self.services:
            service_health = self.check_http_endpoint(service)
            health_report['services'][service['name']] = service_health
            
            if service['critical'] and not service_health['healthy']:
                health_report['overall_healthy'] = False
                
            status = "✅" if service_health['healthy'] else "❌"
            print(f"  {status} {service['name']}: {service_health.get('error', 'OK')}", file=sys.stderr)
        
        # Check Supervisor programs
        print("Checking Supervisor programs...", file=sys.stderr)
        supervisor_health = self.check_supervisor_programs()
        health_report['supervisor'] = supervisor_health
        
        if not supervisor_health['healthy']:
            health_report['overall_healthy'] = False
            
        status = "✅" if supervisor_health['healthy'] else "❌"
        print(f"  {status} Supervisor: {supervisor_health.get('error', 'OK')}", file=sys.stderr)
        
        # Check system resources
        print("Checking system resources...", file=sys.stderr)
        disk_health = self.check_disk_space()
        health_report['system']['disk'] = disk_health
        
        if not disk_health['healthy']:
            health_report['overall_healthy'] = False
            
        status = "✅" if disk_health['healthy'] else "❌"
        print(f"  {status} Disk Space: {disk_health.get('error', 'OK')}", file=sys.stderr)
        
        # Calculate total check time
        health_report['check_duration_ms'] = round((time.time() - start_time) * 1000, 2)
        
        return health_report
    
    def main(self):
        """Main health check function"""
        try:
            health_report = self.run_health_check()
            
            # Print summary
            overall_status = "HEALTHY" if health_report['overall_healthy'] else "UNHEALTHY"
            duration = health_report['check_duration_ms']
            
            print(f"Core Pod Health: {overall_status} (checked in {duration}ms)", file=sys.stderr)
            
            # Save detailed report
            try:
                with open('/tmp/core_pod_health.json', 'w') as f:
                    json.dump(health_report, f, indent=2)
            except Exception as e:
                print(f"Warning: Could not save health report: {e}", file=sys.stderr)
            
            # Exit with appropriate code
            if health_report['overall_healthy']:
                print("Core Pod is healthy", file=sys.stderr)
                sys.exit(0)
            else:
                print("Core Pod is unhealthy", file=sys.stderr)
                sys.exit(1)
                
        except Exception as e:
            print(f"Health check failed: {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == '__main__':
    checker = CorePodHealthCheck()
    checker.main()