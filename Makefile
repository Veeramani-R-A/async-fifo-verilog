.RECIPEPREFIX = >

all: sync async async_swap corner

sync:
> iverilog -o sim_s rtl/sync_fifo.v tb/tb_sync_fifo.v && vvp sim_s

async:
> iverilog -o sim_a rtl/async_fifo.v tb/tb_async_fifo.v && vvp sim_a

async_swap:
> iverilog -DSWAP -o sim_b rtl/async_fifo.v tb/tb_async_fifo.v && vvp sim_b

corner:
> iverilog -o sim_c rtl/async_fifo.v tb/tb_async_fifo_corner.v && vvp sim_c

clean:
> rm -f sim_s sim_a sim_b sim_c *.vcd
