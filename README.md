# T35_UART_TEST
## Project Purpose and Goal
This FPGA Project is used for testing the uart.v UART module used in the FPGA Z80 SBC FPGA projects created for the S100 Hobbyist community.
## Required equiment for this test includes:
1. T35 FPGA Module (available to S100Computers Members)
2. JTAG Programmer (available from [Digikey](https://www.digikey.com) and [Mouser](https://www.mouser.com) ):
3. A USB-COM Port Terminal Connection.
4. (Optional) Oscilliscope or Logic Analyzer.
5. Patience!
## Cloning (Downloading)
*Note*: Place the project in your directoy of choice.

Once downloaded, you will need to compile the project with the Efinity toolchain and then program it via the JTAG interface (see Efinix documentation).
After programming, the test code will wait for 15 receive characters before echoing those characters back (this is done to exercise the FIFO.

The default baud-rate and framing settings for this project is 9600 Baud, 8-bit data, and 1 stop bit.  
If you would like to change the baud-rate, you will need to edit the uart.v file and uncomment your chosen baud-rate and recompile.

Currently, the settings are fixed at compile time, but a future version could support a different baud-rate divisor by passing in a baud-rate divisor.

Many thanks to Terry and the S100Computers members for enabling this effort!

