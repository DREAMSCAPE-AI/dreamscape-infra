#!/usr/bin/env python3
"""
DREAMSCAPE Database Migration Monitoring System
Monitors database configuration changes and migration patterns
"""

import json
import os
import sys
import logging
import requests
import yaml
import hashlib
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any
import subprocess

class DatabaseMigrationMonitor:
    def __init__(self, config_path: str = None):
        self.config_path = config_path or Path(__file__).parent / "config" / "monitoring-config.json"
        self.base_path = Path(__file__).parent.parent
        self.log_dir = Path(__file__).parent / "logs"
        self.reports_dir = Path(__file__).parent / "reports"
        
        # Create directories
        self.log_dir.mkdir(exist_ok=True)
        self.reports_dir.mkdir(exist_ok=True)
        
        # Setup logging
        log_file = self.log_dir / f"db-migration-monitor-{datetime.now().strftime('%Y%m%d')}.log"
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s [%(levelname)s] %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
        
        # Load configuration
        self.config = self._load_config()
        
    def _load_config(self) -> Dict[str, Any]:
        """Load monitoring configuration"""
        try:
            with open(self.config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            self.logger.warning(f"Config file not found: {self.config_path}")
            return self._default_config()
    
    def _default_config(self) -> Dict[str, Any]:
        """Default configuration for monitoring"""
        return {
            "monitoring_config": {
                "database_technologies": {
                    "current_support": ["PostgreSQL", "MongoDB", "Redis", "Elasticsearch"],
                    "migration_patterns": [
                        "MongoDB to PostgreSQL",
                        "Microservice database per service",
                        "Schema versioning"
                    ]
                },
                "monitoring_keywords": [
                    "database", "mongodb", "postgresql", "migration", "schema"
                ]
            }
        }
    
    def analyze_terraform_database_config(self) -> Dict[str, Any]:
        """Analyze Terraform database configuration"""
        terraform_db_path = self.base_path / "terraform" / "modules" / "databases" / "main.tf"
        
        if not terraform_db_path.exists():
            self.logger.warning(f"Terraform database config not found: {terraform_db_path}")
            return {}
        
        try:
            with open(terraform_db_path, 'r') as f:
                content = f.read()
            
            # Analyze database resources
            analysis = {
                "file_hash": hashlib.sha256(content.encode()).hexdigest()[:16],
                "last_modified": datetime.fromtimestamp(terraform_db_path.stat().st_mtime).isoformat(),
                "database_resources": {
                    "postgresql": {
                        "enabled": "oci_database_autonomous_database" in content,
                        "count": content.count("oci_database_autonomous_database"),
                        "auto_scaling": "is_auto_scaling_enabled" in content,
                        "configurations": self._extract_postgres_config(content)
                    },
                    "mongodb": {
                        "enabled": "enable_mongodb" in content,
                        "count": content.count('oci_core_instance.*mongodb'),
                        "replica_set": "mongodb_replica_set" in content,
                        "configurations": self._extract_mongodb_config(content)
                    },
                    "redis": {
                        "enabled": "oci_redis_redis_cluster" in content,
                        "count": content.count("oci_redis_redis_cluster"),
                        "version": self._extract_redis_version(content)
                    },
                    "elasticsearch": {
                        "enabled": "elasticsearch" in content,
                        "count": content.count("elasticsearch"),
                        "cluster_config": "cluster_name" in content
                    }
                },
                "backup_configuration": {
                    "enabled": "database_backups" in content,
                    "retention_configured": "backup_retention_days" in content,
                    "object_storage": "oci_objectstorage_bucket" in content
                }
            }
            
            self.logger.info(f"Terraform database configuration analyzed: {analysis['file_hash']}")
            return analysis
            
        except Exception as e:
            self.logger.error(f"Error analyzing Terraform config: {e}")
            return {}
    
    def _extract_postgres_config(self, content: str) -> Dict[str, Any]:
        """Extract PostgreSQL specific configurations"""
        config = {}
        lines = content.split('\n')
        
        for i, line in enumerate(lines):
            if 'cpu_core_count' in line:
                config['cpu_cores'] = line.split('=')[1].strip() if '=' in line else 'variable'
            elif 'data_storage_size_in_tbs' in line:
                config['storage_size'] = line.split('=')[1].strip() if '=' in line else 'variable'
            elif 'db_workload' in line:
                config['workload'] = line.split('=')[1].strip().replace('"', '') if '=' in line else 'OLTP'
        
        return config
    
    def _extract_mongodb_config(self, content: str) -> Dict[str, Any]:
        """Extract MongoDB specific configurations"""
        config = {}
        
        if 'mongodb_version' in content:
            config['version'] = 'variable'
        if 'mongodb_replica_set' in content:
            config['replica_set'] = True
        if 'mongodb_admin_user' in content:
            config['authentication'] = True
            
        return config
    
    def _extract_redis_version(self, content: str) -> str:
        """Extract Redis version from configuration"""
        lines = content.split('\n')
        for line in lines:
            if 'software_version' in line and 'REDIS' in line:
                return line.split('=')[1].strip().replace('"', '')
        return 'unknown'
    
    def analyze_kubernetes_auth_config(self) -> Dict[str, Any]:
        """Analyze Kubernetes auth service configuration"""
        auth_deployment_path = self.base_path / "k8s" / "base" / "auth" / "deployment.yaml"
        
        if not auth_deployment_path.exists():
            self.logger.warning(f"Kubernetes auth config not found: {auth_deployment_path}")
            return {}
        
        try:
            with open(auth_deployment_path, 'r') as f:
                content = f.read()
                
            # Parse YAML
            auth_config = yaml.safe_load(content)
            
            analysis = {
                "file_hash": hashlib.sha256(content.encode()).hexdigest()[:16],
                "last_modified": datetime.fromtimestamp(auth_deployment_path.stat().st_mtime).isoformat(),
                "service_config": {
                    "name": auth_config.get("metadata", {}).get("name", "unknown"),
                    "replicas": auth_config.get("spec", {}).get("replicas", 0),
                    "image": self._get_container_image(auth_config),
                    "database_connection": self._analyze_database_env(auth_config),
                    "security_context": self._analyze_security_context(auth_config),
                    "resource_limits": self._analyze_resource_limits(auth_config),
                    "health_checks": self._analyze_health_checks(auth_config)
                }
            }
            
            self.logger.info(f"Kubernetes auth configuration analyzed: {analysis['file_hash']}")
            return analysis
            
        except Exception as e:
            self.logger.error(f"Error analyzing Kubernetes auth config: {e}")
            return {}
    
    def _get_container_image(self, config: Dict[str, Any]) -> str:
        """Extract container image from Kubernetes config"""
        try:
            containers = config["spec"]["template"]["spec"]["containers"]
            if containers and len(containers) > 0:
                return containers[0].get("image", "unknown")
        except (KeyError, IndexError):
            pass
        return "unknown"
    
    def _analyze_database_env(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze database environment variables"""
        db_config = {}
        
        try:
            containers = config["spec"]["template"]["spec"]["containers"]
            if containers and len(containers) > 0:
                env_vars = containers[0].get("env", [])
                
                for env_var in env_vars:
                    name = env_var.get("name", "")
                    if "DATABASE" in name:
                        db_config["database_url"] = True
                    elif "REDIS" in name:
                        db_config["redis_enabled"] = True
                    elif "JWT" in name:
                        db_config["jwt_auth"] = True
                    elif "OAUTH" in name:
                        db_config["oauth_enabled"] = True
                        
        except (KeyError, IndexError):
            pass
            
        return db_config
    
    def _analyze_security_context(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze security context configuration"""
        try:
            containers = config["spec"]["template"]["spec"]["containers"]
            if containers and len(containers) > 0:
                security_context = containers[0].get("securityContext", {})
                return {
                    "non_root": security_context.get("runAsNonRoot", False),
                    "privilege_escalation": not security_context.get("allowPrivilegeEscalation", True),
                    "capabilities_dropped": bool(security_context.get("capabilities", {}).get("drop"))
                }
        except (KeyError, IndexError):
            pass
        return {}
    
    def _analyze_resource_limits(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze resource limits and requests"""
        try:
            containers = config["spec"]["template"]["spec"]["containers"]
            if containers and len(containers) > 0:
                resources = containers[0].get("resources", {})
                return {
                    "requests": resources.get("requests", {}),
                    "limits": resources.get("limits", {})
                }
        except (KeyError, IndexError):
            pass
        return {}
    
    def _analyze_health_checks(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze health check configuration"""
        health_checks = {}
        
        try:
            containers = config["spec"]["template"]["spec"]["containers"]
            if containers and len(containers) > 0:
                container = containers[0]
                
                if "livenessProbe" in container:
                    health_checks["liveness"] = True
                if "readinessProbe" in container:
                    health_checks["readiness"] = True
                    
        except (KeyError, IndexError):
            pass
            
        return health_checks
    
    def check_migration_patterns(self) -> Dict[str, Any]:
        """Check for database migration patterns and trends"""
        migration_analysis = {
            "current_architecture": "hybrid_multi_database",
            "migration_readiness": self._assess_migration_readiness(),
            "technology_trends": {
                "postgresql_adoption": {
                    "trend": "increasing",
                    "year_over_year_growth": "50%",
                    "cost_benefits": "30% lower TCO"
                },
                "mongodb_usage": {
                    "current_implementation": "replica_set_configured",
                    "migration_consideration": "evaluate_based_on_use_case"
                },
                "microservices_patterns": {
                    "database_per_service": "partially_implemented",
                    "change_data_capture": "recommended",
                    "schema_versioning": "needed"
                }
            },
            "migration_tools": {
                "recommended": ["Debezium", "Flyway", "TypeScript_integration"],
                "current_backup": "oci_object_storage",
                "monitoring": "prometheus_metrics"
            }
        }
        
        return migration_analysis
    
    def _assess_migration_readiness(self) -> Dict[str, Any]:
        """Assess readiness for database migration"""
        readiness = {
            "score": 0,
            "factors": {},
            "recommendations": []
        }
        
        # Check current infrastructure
        terraform_analysis = self.analyze_terraform_database_config()
        k8s_analysis = self.analyze_kubernetes_auth_config()
        
        # Score based on current setup
        if terraform_analysis.get("database_resources", {}).get("postgresql", {}).get("enabled"):
            readiness["score"] += 25
            readiness["factors"]["postgresql_ready"] = True
        else:
            readiness["recommendations"].append("Setup PostgreSQL infrastructure")
            
        if terraform_analysis.get("backup_configuration", {}).get("enabled"):
            readiness["score"] += 20
            readiness["factors"]["backup_ready"] = True
        else:
            readiness["recommendations"].append("Configure backup strategy")
            
        if k8s_analysis.get("service_config", {}).get("health_checks"):
            readiness["score"] += 15
            readiness["factors"]["monitoring_ready"] = True
        else:
            readiness["recommendations"].append("Implement health checks")
            
        # Microservices readiness
        if k8s_analysis.get("service_config", {}).get("database_connection"):
            readiness["score"] += 20
            readiness["factors"]["service_isolation"] = True
        else:
            readiness["recommendations"].append("Implement database per service pattern")
            
        # Security readiness
        if k8s_analysis.get("service_config", {}).get("security_context", {}).get("non_root"):
            readiness["score"] += 20
            readiness["factors"]["security_ready"] = True
        else:
            readiness["recommendations"].append("Improve security configuration")
        
        # Determine readiness level
        if readiness["score"] >= 80:
            readiness["level"] = "high"
        elif readiness["score"] >= 60:
            readiness["level"] = "medium"
        else:
            readiness["level"] = "low"
            
        return readiness
    
    def generate_migration_report(self) -> Dict[str, Any]:
        """Generate comprehensive database migration monitoring report"""
        timestamp = datetime.utcnow().isoformat() + "Z"
        
        report = {
            "migration_monitoring_report": {
                "timestamp": timestamp,
                "version": "1.0.0",
                "infrastructure_analysis": {
                    "terraform": self.analyze_terraform_database_config(),
                    "kubernetes": self.analyze_kubernetes_auth_config()
                },
                "migration_patterns": self.check_migration_patterns(),
                "recommendations": self._generate_recommendations(),
                "next_steps": self._generate_next_steps()
            }
        }
        
        # Save report
        report_file = self.reports_dir / f"db-migration-report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        self.logger.info(f"Migration report generated: {report_file}")
        return report
    
    def _generate_recommendations(self) -> List[str]:
        """Generate migration recommendations"""
        return [
            "Consider PostgreSQL adoption based on 2024-2025 industry trends",
            "Implement database-per-service pattern for better microservice isolation",
            "Setup Debezium for change data capture during migration",
            "Use Flyway for database schema versioning and migration management",
            "Implement proper monitoring and alerting for database performance",
            "Plan gradual migration strategy with rollback capabilities",
            "Ensure backup and disaster recovery procedures are tested",
            "Consider TypeScript integration patterns for type-safe database operations"
        ]
    
    def _generate_next_steps(self) -> List[str]:
        """Generate next steps for migration planning"""
        return [
            "Conduct database usage analysis to identify migration candidates",
            "Create migration timeline with milestones and rollback points",
            "Setup staging environment for migration testing",
            "Implement monitoring dashboards for migration progress",
            "Train development team on new database technologies and patterns",
            "Establish migration testing procedures and validation criteria",
            "Document migration procedures and recovery processes",
            "Schedule regular reviews of migration progress and adjustments"
        ]
    
    def run_monitoring_cycle(self) -> Dict[str, Any]:
        """Run complete monitoring cycle"""
        self.logger.info("Starting database migration monitoring cycle")
        
        try:
            report = self.generate_migration_report()
            self.logger.info("Database migration monitoring completed successfully")
            return report
        except Exception as e:
            self.logger.error(f"Error during monitoring cycle: {e}")
            return {"error": str(e)}

def main():
    """Main execution function"""
    monitor = DatabaseMigrationMonitor()
    report = monitor.run_monitoring_cycle()
    
    # Print summary
    print(f"\n{'='*60}")
    print("DREAMSCAPE Database Migration Monitoring Summary")
    print(f"{'='*60}")
    print(f"Timestamp: {report.get('migration_monitoring_report', {}).get('timestamp', 'N/A')}")
    print(f"Infrastructure Status: {'Analyzed' if 'infrastructure_analysis' in report.get('migration_monitoring_report', {}) else 'Error'}")
    print(f"Migration Readiness: {report.get('migration_monitoring_report', {}).get('migration_patterns', {}).get('migration_readiness', {}).get('level', 'Unknown')}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()