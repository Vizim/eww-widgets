# Elysium Stats Module

A sleek, modular system stats widget built for Eww. Features a premium vertical card design with 5-stage color gradient alerts for system load and temperature. 

It tracks:
- **CPU Usage**
- **RAM Usage**
- **GPU Usage** (NVIDIA)
- **CPU Temperature** (Fahrenheit)
- **Outside Weather** ("Feels like" temp via Open-Meteo)

## Preview
When components are under heavy load or hit high temperatures, the icons and borders smoothly transition from white through various pastel red shades into a deep warning red.

## Dependencies
Ensure the following packages are installed on your system for the polling scripts to work correctly:
- `eww`: The widget engine itself.
- `procps`: For `top` and `free` commands (CPU/RAM).
- `nvidia-smi`: For pulling NVIDIA GPU utilization.
- `lm-sensors`: For pulling CPU temperature via `sensors`.
- `curl`: For fetching the weather data.
- `jq`: For parsing the weather JSON data.
- *Note: Hack Nerd Font is not required for the primary UI since all icons have been replaced with pure SVG vectors for pixel-perfect centering!*

## Installation & Usage
1. Copy this entire `stats-module` folder into your Eww configuration directory (typically `~/.config/eww/`). 
   - *If you already have an `eww.yuck` file, you can merge the `defwidget`, `defpoll`, and `defwindow` blocks into your existing config.*
2. Ensure the `icons` directory is kept alongside the `eww.yuck` file so the relative paths resolve correctly.
3. Open the widget by running:
   ```bash
   eww open stats-widget
   ```

### Customization
- **Weather Location**: By default, the weather widget pulls data for Lone Tree, Colorado. To change this, open `eww.yuck` and find the `defpoll weather` command. Replace the `latitude=39.5317&longitude=-104.8916` URL parameters with your own coordinates.
- **Thresholds**: If you want the red warning colors to kick in at different thresholds, simply adjust the ternary operators in the `color` and `icon_path` properties inside the `stats` widget block.
