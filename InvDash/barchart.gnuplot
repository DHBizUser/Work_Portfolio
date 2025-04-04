# David Harris 2025-03-04
# Bar chart showing Inventory balances by month

# Started with this example from Davide Gadioli:
# https://github.com/gianfi12/gnuplot-by-example/blob/main/histogram/multiple_serie/plot.gnuplot

# ---------------------------------------------------------

# output format
set terminal pdf size 20,10 enhanced font ",40"
set output 'InventoryOnHand_bar_20250304.pdf'

# set boxwidth 0.5
# set style fill solid
# unset key
# set title 'year sell'
# set ylabel '(yen)'
# set format "%'.0f"
# set decimalsign locale; set decimalsign "."


# plot command
plot '< "D:\WinApps\SQLite_ODBC_Driver_Win64\sqlite3.exe" "D:\home\RM06analyst\InvDash2.0\ProcessedDB\precombine01_20250304.db" ".mode tabs" "select rowid,Mtype,sum(UnrestrictedValue) from MB52combined group by Mtype;"' using 1:3