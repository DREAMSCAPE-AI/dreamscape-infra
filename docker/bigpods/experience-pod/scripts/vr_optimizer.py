#!/usr/bin/env python3
"""
DreamScape Experience Pod - VR Content Optimizer
DR-328: Automated optimization and conversion of VR/360° content
Big Pods Architecture - Background Processing Service
Performance target: <2s FCL, optimized asset delivery
"""

import os
import sys
import time
import json
import logging
import hashlib
import subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from typing import List, Dict, Optional, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/supervisor/vr-optimizer.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('VROptimizer')

@dataclass
class VROptimizationTask:
    """VR content optimization task definition"""
    source_path: str
    target_formats: List[str]
    quality_settings: Dict[str, int]
    priority: int = 1
    metadata: Optional[Dict] = None

class VRContentOptimizer:
    """
    Advanced VR content optimization service for Experience Pod
    Handles multiple format conversion, quality optimization, and streaming preparation
    """
    
    def __init__(self):
        self.vr_source_path = os.getenv('VR_SOURCE_PATH', '/usr/share/nginx/html/vr')
        self.vr_cache_path = os.getenv('VR_CACHE_PATH', '/var/cache/nginx/vr')
        self.optimization_quality = int(os.getenv('OPTIMIZATION_QUALITY', '85'))
        self.max_workers = int(os.getenv('VR_OPTIMIZER_WORKERS', '2'))
        self.supported_formats = ['webp', 'avif', 'jpg', 'png']
        self.vr_qualities = {
            'hq': {'quality': 90, 'max_width': 4096},
            'mq': {'quality': 80, 'max_width': 2048}, 
            'lq': {'quality': 70, 'max_width': 1024}
        }
        
        # Create necessary directories
        Path(self.vr_cache_path).mkdir(parents=True, exist_ok=True)
        Path(f"{self.vr_cache_path}/hq").mkdir(parents=True, exist_ok=True)
        Path(f"{self.vr_cache_path}/mq").mkdir(parents=True, exist_ok=True)
        Path(f"{self.vr_cache_path}/lq").mkdir(parents=True, exist_ok=True)
        Path(f"{self.vr_cache_path}/thumbs").mkdir(parents=True, exist_ok=True)
        
        logger.info(f"VR Optimizer initialized - Source: {self.vr_source_path}, Cache: {self.vr_cache_path}")

    def get_file_hash(self, filepath: str) -> str:
        """Generate MD5 hash for file content"""
        hash_md5 = hashlib.md5()
        try:
            with open(filepath, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except Exception as e:
            logger.error(f"Failed to hash file {filepath}: {e}")
            return ""

    def is_vr_content(self, filepath: str) -> bool:
        """Check if file is VR/panoramic content based on dimensions and metadata"""
        try:
            # Get image dimensions
            result = subprocess.run([
                'identify', '-format', '%w %h', filepath
            ], capture_output=True, text=True, check=True)
            
            width, height = map(int, result.stdout.strip().split())
            
            # VR content typically has 2:1 aspect ratio for equirectangular projection
            aspect_ratio = width / height
            is_panoramic = abs(aspect_ratio - 2.0) < 0.1
            
            # Also check minimum size (VR content is usually large)
            min_resolution = width >= 1024 and height >= 512
            
            return is_panoramic and min_resolution
            
        except Exception as e:
            logger.warning(f"Could not analyze image dimensions for {filepath}: {e}")
            return False

    def optimize_vr_image(self, source_path: str, target_path: str, format_type: str, quality: str) -> bool:
        """Optimize VR image for specific format and quality"""
        try:
            quality_config = self.vr_qualities[quality]
            target_quality = quality_config['quality']
            max_width = quality_config['max_width']
            
            # Prepare optimization command based on format
            if format_type == 'webp':
                cmd = [
                    'cwebp',
                    '-q', str(target_quality),
                    '-resize', str(max_width), '0',
                    '-metadata', 'none',
                    '-method', '6',
                    source_path,
                    '-o', target_path
                ]
            elif format_type == 'avif':
                cmd = [
                    'magick', source_path,
                    '-resize', f"{max_width}x",
                    '-quality', str(target_quality),
                    '-format', 'avif',
                    target_path
                ]
            elif format_type in ['jpg', 'jpeg']:
                cmd = [
                    'magick', source_path,
                    '-resize', f"{max_width}x",
                    '-quality', str(target_quality),
                    '-strip',
                    '-interlace', 'Plane',
                    target_path
                ]
            else:
                logger.warning(f"Unsupported format: {format_type}")
                return False
            
            # Execute optimization
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0:
                # Verify output file was created and has reasonable size
                if os.path.exists(target_path) and os.path.getsize(target_path) > 1000:
                    original_size = os.path.getsize(source_path)
                    optimized_size = os.path.getsize(target_path)
                    compression_ratio = (1 - optimized_size / original_size) * 100
                    
                    logger.info(f"Optimized {source_path} -> {target_path} "
                              f"({format_type}/{quality}) - {compression_ratio:.1f}% reduction")
                    return True
                else:
                    logger.error(f"Output file {target_path} is invalid or too small")
                    return False
            else:
                logger.error(f"Optimization failed: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            logger.error(f"Optimization timeout for {source_path}")
            return False
        except Exception as e:
            logger.error(f"Optimization error for {source_path}: {e}")
            return False

    def create_vr_thumbnail(self, source_path: str, thumb_path: str) -> bool:
        """Create thumbnail for VR content"""
        try:
            cmd = [
                'magick', source_path,
                '-resize', '300x150^',
                '-gravity', 'center',
                '-crop', '300x150+0+0',
                '-quality', '80',
                '-strip',
                thumb_path
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0 and os.path.exists(thumb_path):
                logger.info(f"Created thumbnail: {thumb_path}")
                return True
            else:
                logger.error(f"Thumbnail creation failed: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Thumbnail creation error: {e}")
            return False

    def generate_vr_metadata(self, filepath: str) -> Dict:
        """Generate metadata for VR content"""
        try:
            # Get basic image info
            result = subprocess.run([
                'identify', '-format', 
                '{"width":%w,"height":%h,"format":"%m","size":%b,"colorspace":"%[colorspace]"}',
                filepath
            ], capture_output=True, text=True, check=True)
            
            metadata = json.loads(result.stdout.strip())
            
            # Add VR-specific metadata
            aspect_ratio = metadata['width'] / metadata['height']
            metadata.update({
                'is_vr_content': self.is_vr_content(filepath),
                'aspect_ratio': round(aspect_ratio, 2),
                'projection_type': 'equirectangular' if abs(aspect_ratio - 2.0) < 0.1 else 'unknown',
                'file_hash': self.get_file_hash(filepath),
                'optimization_timestamp': int(time.time())
            })
            
            return metadata
            
        except Exception as e:
            logger.error(f"Metadata generation failed for {filepath}: {e}")
            return {}

    def process_vr_content(self, source_file: str) -> bool:
        """Process single VR content file - create all quality variants and formats"""
        try:
            source_path = Path(source_file)
            filename_base = source_path.stem
            
            # Skip if not actual VR content
            if not self.is_vr_content(str(source_path)):
                logger.info(f"Skipping non-VR content: {source_file}")
                return True
            
            logger.info(f"Processing VR content: {source_file}")
            
            # Generate metadata
            metadata = self.generate_vr_metadata(str(source_path))
            
            # Create thumbnail
            thumb_path = f"{self.vr_cache_path}/thumbs/{filename_base}.jpg"
            self.create_vr_thumbnail(str(source_path), thumb_path)
            
            success_count = 0
            total_variants = 0
            
            # Generate all quality variants for supported formats
            for quality in ['hq', 'mq', 'lq']:
                for format_type in ['webp', 'avif', 'jpg']:
                    total_variants += 1
                    target_dir = f"{self.vr_cache_path}/{quality}"
                    target_file = f"{target_dir}/{filename_base}.{format_type}"
                    
                    # Skip if already exists and source hasn't changed
                    if os.path.exists(target_file):
                        target_mtime = os.path.getmtime(target_file)
                        source_mtime = os.path.getmtime(str(source_path))
                        if target_mtime > source_mtime:
                            logger.debug(f"Skipping up-to-date variant: {target_file}")
                            success_count += 1
                            continue
                    
                    if self.optimize_vr_image(str(source_path), target_file, format_type, quality):
                        success_count += 1
            
            # Save metadata file
            metadata_file = f"{self.vr_cache_path}/{filename_base}.json"
            with open(metadata_file, 'w') as f:
                json.dump(metadata, f, indent=2)
            
            success_rate = success_count / total_variants * 100
            logger.info(f"VR content processing completed: {source_file} - "
                       f"{success_count}/{total_variants} variants ({success_rate:.1f}%)")
            
            return success_count > 0
            
        except Exception as e:
            logger.error(f"VR content processing failed for {source_file}: {e}")
            return False

    def scan_and_optimize(self):
        """Scan VR source directory and optimize all content"""
        try:
            logger.info("Starting VR content optimization scan...")
            
            # Find all image files in source directory
            image_extensions = ['.jpg', '.jpeg', '.png', '.tiff', '.bmp']
            vr_files = []
            
            for ext in image_extensions:
                pattern = f"**/*{ext}"
                files = list(Path(self.vr_source_path).glob(pattern))
                vr_files.extend([str(f) for f in files])
            
            if not vr_files:
                logger.info("No VR content found in source directory")
                return
            
            logger.info(f"Found {len(vr_files)} potential VR files to process")
            
            # Process files using thread pool
            with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
                results = list(executor.map(self.process_vr_content, vr_files))
            
            successful = sum(results)
            logger.info(f"VR optimization completed: {successful}/{len(vr_files)} files processed successfully")
            
        except Exception as e:
            logger.error(f"VR optimization scan failed: {e}")

    def cleanup_cache(self):
        """Clean up old cache files and optimize storage"""
        try:
            logger.info("Cleaning up VR cache...")
            
            # Remove cache files older than 30 days
            cutoff_time = time.time() - (30 * 24 * 60 * 60)
            
            for cache_dir in ['hq', 'mq', 'lq', 'thumbs']:
                cache_path = Path(f"{self.vr_cache_path}/{cache_dir}")
                if cache_path.exists():
                    for file_path in cache_path.iterdir():
                        if file_path.is_file() and file_path.stat().st_mtime < cutoff_time:
                            file_path.unlink()
                            logger.debug(f"Removed old cache file: {file_path}")
            
            logger.info("VR cache cleanup completed")
            
        except Exception as e:
            logger.error(f"Cache cleanup failed: {e}")

    def run_optimization_loop(self):
        """Main optimization loop"""
        logger.info("Starting VR Content Optimizer service...")
        
        # Initial optimization run
        self.scan_and_optimize()
        
        # Continuous monitoring loop
        optimization_interval = int(os.getenv('VR_OPTIMIZATION_INTERVAL', '3600'))  # 1 hour
        cleanup_interval = int(os.getenv('VR_CLEANUP_INTERVAL', '86400'))  # 24 hours
        
        last_cleanup = time.time()
        
        while True:
            try:
                time.sleep(optimization_interval)
                
                logger.info("Running scheduled VR optimization...")
                self.scan_and_optimize()
                
                # Run cleanup periodically
                if time.time() - last_cleanup > cleanup_interval:
                    self.cleanup_cache()
                    last_cleanup = time.time()
                
            except KeyboardInterrupt:
                logger.info("VR Optimizer stopping...")
                break
            except Exception as e:
                logger.error(f"Optimization loop error: {e}")
                time.sleep(60)  # Wait before retrying

def main():
    """Main entry point"""
    try:
        optimizer = VRContentOptimizer()
        optimizer.run_optimization_loop()
    except Exception as e:
        logger.error(f"VR Optimizer failed to start: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()