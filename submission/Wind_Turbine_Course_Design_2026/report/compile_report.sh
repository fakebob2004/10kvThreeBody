#!/bin/sh
set -eu
cd "$(dirname "$0")"
tectonic Wind_Turbine_Dual_Model_Report.tex
printf '%s\n' 'Report generated: Wind_Turbine_Dual_Model_Report.pdf'
