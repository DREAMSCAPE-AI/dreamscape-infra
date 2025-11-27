#!/usr/bin/env python3
"""
Crash Notifier for DreamScape Business Pod
DR-327: INFRA-011 - Handles process crash notifications and alerts
"""

import sys
import json
import logging
from datetime import datetime
from supervisor import childutils

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('crash-notifier')

class CrashNotifier:
    """Handles Supervisor process state events and notifications"""
    
    def __init__(self):
        self.critical_processes = ['voyage-service', 'ai-service', 'payment-service']
        self.restart_attempts = {}
        self.max_restart_attempts = 3
        self.notification_file = '/tmp/crash_notifications.json'
        
    def load_notifications_history(self):
        """Load previous crash notifications"""
        try:
            with open(self.notification_file, 'r') as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return []
    
    def save_notification(self, notification):
        """Save crash notification to file"""
        try:
            history = self.load_notifications_history()
            history.append(notification)
            
            # Keep only last 50 notifications
            if len(history) > 50:
                history = history[-50:]
                
            with open(self.notification_file, 'w') as f:
                json.dump(history, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving notification: {e}")
    
    def handle_process_exit(self, headers, payload):
        """Handle PROCESS_STATE_EXITED event"""
        process_name = headers['processname']
        from_state = headers['from_state']
        
        logger.warning(f"Process {process_name} exited from state {from_state}")
        
        notification = {
            'timestamp': datetime.utcnow().isoformat(),
            'event_type': 'PROCESS_EXITED',
            'process_name': process_name,
            'from_state': from_state,
            'headers': dict(headers),
            'severity': 'warning' if process_name in self.critical_processes else 'info'
        }
        
        self.save_notification(notification)
        
        if process_name in self.critical_processes:
            logger.error(f"CRITICAL: Critical process {process_name} has exited!")
            self.handle_critical_process_exit(process_name, headers)
    
    def handle_process_fatal(self, headers, payload):
        """Handle PROCESS_STATE_FATAL event"""
        process_name = headers['processname']
        
        logger.error(f"Process {process_name} entered FATAL state")
        
        notification = {
            'timestamp': datetime.utcnow().isoformat(),
            'event_type': 'PROCESS_FATAL',
            'process_name': process_name,
            'headers': dict(headers),
            'severity': 'critical' if process_name in self.critical_processes else 'warning'
        }
        
        self.save_notification(notification)
        
        if process_name in self.critical_processes:
            logger.critical(f"FATAL: Critical process {process_name} is in FATAL state!")
            self.handle_critical_process_fatal(process_name, headers)
    
    def handle_critical_process_exit(self, process_name, headers):
        """Handle exit of critical processes"""
        # Track restart attempts
        if process_name not in self.restart_attempts:
            self.restart_attempts[process_name] = 0
        
        self.restart_attempts[process_name] += 1
        
        if self.restart_attempts[process_name] <= self.max_restart_attempts:
            logger.info(f"Attempting restart {self.restart_attempts[process_name]}/{self.max_restart_attempts} for {process_name}")
            # Supervisor will handle the restart automatically based on autorestart=true
        else:
            logger.critical(f"Process {process_name} has exceeded maximum restart attempts!")
            self.send_alert(f"Process {process_name} has failed {self.max_restart_attempts} times and needs manual intervention")
    
    def handle_critical_process_fatal(self, process_name, headers):
        """Handle fatal state of critical processes"""
        logger.critical(f"Process {process_name} is in FATAL state - manual intervention required")
        self.send_alert(f"FATAL: Process {process_name} cannot be restarted and is in FATAL state")
    
    def send_alert(self, message):
        """Send alert notification (placeholder for actual alerting system)"""
        alert = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': 'CRITICAL',
            'message': message,
            'source': 'dreamscape-business-pod'
        }
        
        # In a real implementation, this would send to:
        # - Slack/Teams
        # - PagerDuty
        # - Email
        # - Monitoring system (Prometheus AlertManager)
        
        logger.critical(f"ALERT: {message}")
        
        # Write alert to file for external processing
        try:
            with open('/tmp/alerts.json', 'a') as f:
                f.write(json.dumps(alert) + '\n')
        except Exception as e:
            logger.error(f"Error writing alert: {e}")
    
    def run(self):
        """Main event loop"""
        logger.info("Starting DreamScape Crash Notifier")
        
        while True:
            try:
                # Wait for supervisor events
                headers, payload = childutils.listener.wait()
                
                # Parse event
                event_name = headers['eventname']
                
                logger.debug(f"Received event: {event_name}")
                
                if event_name == 'PROCESS_STATE_EXITED':
                    self.handle_process_exit(headers, payload)
                elif event_name == 'PROCESS_STATE_FATAL':
                    self.handle_process_fatal(headers, payload)
                
                # Acknowledge the event
                childutils.listener.ok()
                
            except KeyboardInterrupt:
                logger.info("Crash notifier stopped by user")
                break
            except Exception as e:
                logger.error(f"Unexpected error in crash notifier: {e}")
                childutils.listener.fail()


if __name__ == '__main__':
    notifier = CrashNotifier()
    notifier.run()