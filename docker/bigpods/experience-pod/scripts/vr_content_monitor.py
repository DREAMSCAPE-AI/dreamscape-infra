#!/usr/bin/env python3
"""
DreamScape Experience Pod - VR Content Monitor
DR-328: Monitor VR content changes and optimization status
Big Pods Architecture - VR Content Tracking Service
"""

import sys
import os
import json
import time
import logging
from pathlib import Path
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/supervisor/vr-content-monitor.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('VRContentMonitor')

class VRContentMonitor:
    def __init__(self):
        self.vr_source_path = os.getenv('VR_SOURCE_PATH', '/usr/share/nginx/html/vr')
        self.vr_cache_path = os.getenv('VR_CACHE_PATH', '/var/cache/nginx/vr')
        self.last_scan_results = {}
        
    def scan_vr_content(self):
        """Scan VR content directories and track changes"""
        try:
            results = {
                'timestamp': datetime.now().isoformat(),
                'source_content': {},
                'cached_content': {},
                'optimization_status': {}
            }
            
            # Scan source content
            source_path = Path(self.vr_source_path)
            if source_path.exists():
                for file_path in source_path.rglob('*'):
                    if file_path.is_file() and file_path.suffix.lower() in ['.jpg', '.jpeg', '.png', '.webp', '.avif']:
                        relative_path = str(file_path.relative_to(source_path))
                        results['source_content'][relative_path] = {
                            'size': file_path.stat().st_size,
                            'modified': file_path.stat().st_mtime
                        }
            
            # Scan cached content
            cache_path = Path(self.vr_cache_path)
            if cache_path.exists():
                for quality_dir in ['hq', 'mq', 'lq', 'thumbs']:
                    quality_path = cache_path / quality_dir
                    if quality_path.exists():
                        for file_path in quality_path.iterdir():
                            if file_path.is_file():
                                key = f"{quality_dir}/{file_path.name}"
                                results['cached_content'][key] = {
                                    'size': file_path.stat().st_size,
                                    'modified': file_path.stat().st_mtime
                                }
            
            # Check optimization status
            for source_file in results['source_content']:
                base_name = Path(source_file).stem
                optimized_variants = []
                
                for quality in ['hq', 'mq', 'lq']:
                    for ext in ['webp', 'avif', 'jpg']:
                        cache_key = f"{quality}/{base_name}.{ext}"
                        if cache_key in results['cached_content']:
                            optimized_variants.append(cache_key)
                
                results['optimization_status'][source_file] = {
                    'variants_count': len(optimized_variants),
                    'variants': optimized_variants,
                    'fully_optimized': len(optimized_variants) >= 9  # 3 qualities × 3 formats
                }
            
            return results
            
        except Exception as e:
            logger.error(f"Error scanning VR content: {e}")
            return None
    
    def analyze_content_changes(self, current_results):
        """Analyze changes since last scan"""
        if not self.last_scan_results:
            return {
                'new_files': list(current_results['source_content'].keys()),
                'deleted_files': [],
                'modified_files': [],
                'optimization_changes': {}
            }
        
        changes = {
            'new_files': [],
            'deleted_files': [],
            'modified_files': [],
            'optimization_changes': {}
        }
        
        # Find new and modified files
        for file_path, info in current_results['source_content'].items():
            if file_path not in self.last_scan_results['source_content']:
                changes['new_files'].append(file_path)
            elif info['modified'] > self.last_scan_results['source_content'][file_path]['modified']:
                changes['modified_files'].append(file_path)
        
        # Find deleted files
        for file_path in self.last_scan_results['source_content']:
            if file_path not in current_results['source_content']:
                changes['deleted_files'].append(file_path)
        
        # Check optimization changes
        for file_path in current_results['optimization_status']:
            current_status = current_results['optimization_status'][file_path]
            last_status = self.last_scan_results.get('optimization_status', {}).get(file_path, {})
            
            if current_status.get('variants_count', 0) != last_status.get('variants_count', 0):
                changes['optimization_changes'][file_path] = {
                    'old_variants': last_status.get('variants_count', 0),
                    'new_variants': current_status.get('variants_count', 0),
                    'fully_optimized': current_status.get('fully_optimized', False)
                }
        
        return changes

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
        
        # Create monitor instance and scan content
        monitor = VRContentMonitor()
        scan_results = monitor.scan_vr_content()
        
        if scan_results:
            # Analyze changes
            changes = monitor.analyze_content_changes(scan_results)
            
            # Log summary
            source_count = len(scan_results['source_content'])
            cached_count = len(scan_results['cached_content'])
            optimized_count = sum(1 for status in scan_results['optimization_status'].values() 
                                if status.get('fully_optimized', False))
            
            logger.info(f"🎮 VR Content Status: {source_count} source files, "
                       f"{cached_count} cached variants, {optimized_count} fully optimized")
            
            # Log changes if any
            if changes['new_files']:
                logger.info(f"📥 New VR files: {len(changes['new_files'])}")
            if changes['modified_files']:
                logger.info(f"📝 Modified VR files: {len(changes['modified_files'])}")
            if changes['deleted_files']:
                logger.info(f"🗑️ Deleted VR files: {len(changes['deleted_files'])}")
            if changes['optimization_changes']:
                logger.info(f"⚡ Optimization changes: {len(changes['optimization_changes'])}")
            
            # Update last scan results
            monitor.last_scan_results = scan_results
        
        # Send OK response to supervisor
        sys.stdout.write('RESULT 2\nOK')
        sys.stdout.flush()
        
    except Exception as e:
        logger.error(f"Error processing VR content monitoring event: {e}")
        sys.stdout.write('RESULT 2\nFAIL')
        sys.stdout.flush()

def main():
    """Main event processing loop"""
    logger.info("🎮 Experience Pod VR Content Monitor started")
    
    # Send READY to supervisor
    sys.stdout.write('READY\n')
    sys.stdout.flush()
    
    while True:
        try:
            process_tick_event()
        except KeyboardInterrupt:
            logger.info("VR Content Monitor stopping...")
            break
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()