#!/usr/bin/env python3
"""
SRAM Compilation Script
Automates the SRAM generation process with various configurations
"""

import os
import sys
import json
import argparse
from pathlib import Path

# Add src directory to path
sys.path.append(str(Path(__file__).parent.parent / 'src'))

from compiler.sram_compiler import SRAMCompiler

def create_config_file(config_name: str, output_dir: str) -> str:
    """Create a configuration file from predefined templates"""
    
    # Load configuration templates
    config_file = Path(__file__).parent.parent / 'config' / 'sram_configs.json'
    
    if not config_file.exists():
        print(f"Configuration file not found: {config_file}")
        return None
    
    with open(config_file, 'r') as f:
        configs = json.load(f)
    
    if config_name not in configs['example_configs']:
        print(f"Configuration '{config_name}' not found in templates")
        print(f"Available configurations: {list(configs['example_configs'].keys())}")
        return None
    
    # Create output configuration file
    output_config = Path(output_dir) / f"{config_name}_config.json"
    output_config.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_config, 'w') as f:
        json.dump(configs['example_configs'][config_name], f, indent=2)
    
    return str(output_config)

def run_power_analysis(compiler: SRAMCompiler, output_dir: str):
    """Run comprehensive power analysis"""
    print("Running power analysis...")
    
    # Analyze different activity factors
    activity_factors = [0.01, 0.05, 0.1, 0.2, 0.5]
    results = {}
    
    for activity in activity_factors:
        power_est = compiler.estimate_power(activity)
        results[f"activity_{activity}"] = power_est
    
    # Save power analysis results
    power_file = Path(output_dir) / "power_analysis.json"
    with open(power_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"Power analysis saved to: {power_file}")

def run_area_analysis(compiler: SRAMCompiler, output_dir: str):
    """Run area analysis"""
    print("Running area analysis...")
    
    area_est = compiler.estimate_area()
    timing_est = compiler.estimate_timing()
    
    analysis = {
        "area": area_est,
        "timing": timing_est
    }
    
    # Save analysis results
    analysis_file = Path(output_dir) / "area_timing_analysis.json"
    with open(analysis_file, 'w') as f:
        json.dump(analysis, f, indent=2)
    
    print(f"Area and timing analysis saved to: {analysis_file}")

def generate_comparison_report(configs: list, output_dir: str):
    """Generate comparison report for multiple configurations"""
    print("Generating comparison report...")
    
    comparison_data = []
    
    for config_name in configs:
        config_file = create_config_file(config_name, output_dir)
        if not config_file:
            continue
            
        compiler = SRAMCompiler(config_file)
        
        power_est = compiler.estimate_power()
        area_est = compiler.estimate_area()
        timing_est = compiler.estimate_timing()
        
        comparison_data.append({
            "config_name": config_name,
            "configuration": compiler.config.__dict__,
            "power": power_est,
            "area": area_est,
            "timing": timing_est
        })
    
    # Save comparison report
    comparison_file = Path(output_dir) / "comparison_report.json"
    with open(comparison_file, 'w') as f:
        json.dump(comparison_data, f, indent=2)
    
    # Generate markdown report
    generate_markdown_comparison(comparison_data, output_dir)
    
    print(f"Comparison report saved to: {comparison_file}")

def generate_markdown_comparison(data: list, output_dir: str):
    """Generate markdown comparison report"""
    
    md_content = "# SRAM Configuration Comparison Report\n\n"
    
    # Configuration table
    md_content += "## Configuration Summary\n\n"
    md_content += "| Config | Depth | Width | Banks | Voltage | Process | Power Features |\n"
    md_content += "|--------|-------|-------|-------|---------|---------|----------------|\n"
    
    for item in data:
        config = item['configuration']
        features = []
        if config['power_gating']: features.append('PG')
        if config['clock_gating']: features.append('CG')
        if config['retention_mode']: features.append('RET')
        if config['ecc_enable']: features.append('ECC')
        
        md_content += f"| {item['config_name']} | {config['depth']} | {config['width']} | {config['banks']} | {config['voltage']}V | {config['process_node']}nm | {', '.join(features)} |\n"
    
    # Power comparison
    md_content += "\n## Power Comparison\n\n"
    md_content += "| Config | Dynamic Power (mW) | Static Power (mW) | Total Power (mW) | Retention Power (µW) |\n"
    md_content += "|--------|-------------------|------------------|------------------|--------------------|\n"
    
    for item in data:
        power = item['power']
        md_content += f"| {item['config_name']} | {power['dynamic_power_mw']:.3f} | {power['static_power_mw']:.3f} | {power['total_power_mw']:.3f} | {power['retention_power_uw']:.1f} |\n"
    
    # Area comparison
    md_content += "\n## Area Comparison\n\n"
    md_content += "| Config | Total Area (mm²) | Area Efficiency (%) | Access Time (ns) | Max Frequency (MHz) |\n"
    md_content += "|--------|------------------|-------------------|------------------|--------------------|\n"
    
    for item in data:
        area = item['area']
        timing = item['timing']
        md_content += f"| {item['config_name']} | {area['total_area_mm2']:.4f} | {area['area_efficiency']*100:.1f} | {timing['access_time_ns']:.2f} | {timing['max_frequency_mhz']:.1f} |\n"
    
    # Save markdown report
    md_file = Path(output_dir) / "comparison_report.md"
    with open(md_file, 'w') as f:
        f.write(md_content)

def main():
    parser = argparse.ArgumentParser(description='SRAM Compiler Script')
    parser.add_argument('--config', help='Configuration name or file path')
    parser.add_argument('--output', default='output', help='Output directory')
    parser.add_argument('--generate-verilog', action='store_true', help='Generate Verilog RTL')
    parser.add_argument('--power-analysis', action='store_true', help='Run power analysis')
    parser.add_argument('--area-analysis', action='store_true', help='Run area analysis')
    parser.add_argument('--compare', nargs='+', help='Compare multiple configurations')
    parser.add_argument('--list-configs', action='store_true', help='List available configurations')
    
    args = parser.parse_args()
    
    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # List available configurations
    if args.list_configs:
        config_file = Path(__file__).parent.parent / 'config' / 'sram_configs.json'
        with open(config_file, 'r') as f:
            configs = json.load(f)
        print("Available configurations:")
        for name, config in configs['example_configs'].items():
            print(f"  {name}: {config['depth']}x{config['width']}, {config['banks']} banks, {config['process_node']}nm")
        return
    
    # Compare multiple configurations
    if args.compare:
        generate_comparison_report(args.compare, args.output)
        return
    
    # Single configuration processing
    if not args.config:
        print("Please specify a configuration with --config")
        return
    
    # Create or use configuration file
    if args.config.endswith('.json'):
        config_file = args.config
    else:
        config_file = create_config_file(args.config, args.output)
        if not config_file:
            return
    
    # Create compiler instance
    compiler = SRAMCompiler(config_file)
    
    # Generate Verilog
    if args.generate_verilog:
        verilog_dir = output_dir / "verilog"
        compiler.generate_verilog(str(verilog_dir))
    
    # Run power analysis
    if args.power_analysis:
        run_power_analysis(compiler, args.output)
    
    # Run area analysis
    if args.area_analysis:
        run_area_analysis(compiler, args.output)
    
    # Generate design report
    report_file = output_dir / f"{args.config}_report.md"
    compiler.generate_report(str(report_file))
    
    print(f"SRAM compilation completed. Output in: {output_dir}")

if __name__ == "__main__":
    main()
