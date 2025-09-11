#!/usr/bin/env python3
"""
DreamScape Experience Pod - Crash Notification System
DR-328: Monitor service crashes and send notifications
Big Pods Architecture - Event Listener Service
"""

import sys
import os
import json
import time
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/supervisor/crash-notifier.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('CrashNotifier')

def process_event():
    """Process supervisor events from stdin"""
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
            
            # Parse payload
            event_data = {}
            for line in payload.strip().split('\n'):
                if ':' in line:
                    key, value = line.split(':', 1)
                    event_data[key] = value.strip()
            
            # Process crash event
            if event_data.get('eventname') in ['PROCESS_STATE_FATAL', 'PROCESS_STATE_EXITED']:
                processname = event_data.get('processname', 'unknown')
                from_state = event_data.get('from_state', 'unknown')
                
                logger.warning(f"🚨 Service crash detected: {processname} (from {from_state})")
                
                # Create crash notification
                crash_info = {
                    'timestamp': datetime.now().isoformat(),
                    'service': processname,
                    'from_state': from_state,
                    'event': event_data.get('eventname'),
                    'pid': event_data.get('pid', 'unknown')
                }
                
                # Log crash details
                logger.error(f"Crash details: {json.dumps(crash_info, indent=2)}")
                
                # Here you could add notification logic:
                # - Send webhook
                # - Write to alerting system
                # - Send email/Slack notification
                
        # Send OK response to supervisor
        sys.stdout.write('RESULT 2\nOK')
        sys.stdout.flush()
        
    except Exception as e:
        logger.error(f"Error processing crash event: {e}")
        sys.stdout.write('RESULT 2\nFAIL')
        sys.stdout.flush()

def main():
    """Main event processing loop"""
    logger.info("🚨 Experience Pod Crash Notifier started")
    
    # Send READY to supervisor
    sys.stdout.write('READY\n')
    sys.stdout.flush()
    
    while True:
        try:
            process_event()
        except KeyboardInterrupt:
            logger.info("Crash Notifier stopping...")
            break
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()