// Top Level Taken from the Terry Fox's T35SBCextSD_16 project, so not
// all signals and comments will make sense for the purposes of this
// UART.v test project.
//
// For information on Terry's project, please see:
//     https://github.com/n4tlf/T35SBCextSD_16
//
/************************************************************************
*   FILE:  T35SBCextSD_16_top.v    Ver .3    3/23/23                  	*
*                                                                     	*
*	This project adds SD Card access via an eight-bit SPI Interface		*
*		Work on several "fixes" were also created here first, before	*
*		being applied to several earlier projects						*
*   TFOX, N4TLF March 23, 2023   You are free to use it             	*
*       however you like.  No warranty expressed or implied           	*
*   TFOX, N4TLF, April 15, 2023     SD Card Interface working           *
*   TFOX, N4TLF, April 28, 2023     Interrupt code Seems fine           *
*   TFOX, N4TLF, April 29, 2023     RTC Seems to work, timing looks OK  *
*   TFOX, N4TLF, October 5, 023     Removed need for microcomputer.vhd  *
*                                   to expose hidden CPU clock divider  *
*   TFOX, N4TLF, October 8, 2023    Replaced nop reset to Monitor with  *
*                                   Jump On Reset, ala Altair & IMSAI   *
************************************************************************/

//**************    UART.V INFO FOR TESTING 2/16/24 ************************
//NOTE:  This has been modified by TFOX to comment out one of the tx drivers
//          at lines 90 and 94, which caused errors
//      9/10/23:  Also modified to fix intermitent RX data garbled by
//          adding a register to the rx input that now feeds rx_in

// VERSION TEST Feb.16, 2024 @2345.
//      9,600 baud= no SOH errors, ususally works
//      19,200 baud = NOT SOH retry every second to fourth packet
//            does eventually successfully transfer u.asm, 58 sectors
//      38,400 baud = NOT SOH retry every 5-6 packet, sometimes completes
//              file transfer 58 sectors.
//      57,600 baud = NOT SOH retry every 2-3 packet, sometimes completes
//              file transfer 58 sectors
// test uses u.com, Rx status in port 34, ani 01, jnz status loop
//                  Tx status in port 34, ani 02, jnz status loop
//***********************************************************************

module  t35_uart_test_top(
                                                // FPGA SIGNAL PINS INPUTS
    clockIn,            // 50MHz input from onboard oscillator
    pll0_LOCKED,
    pll0_2MHz,
    pll0_50MHz,         // NOTE:  This also drives SBC_LEDs mux to 
                        // eliminate a build error
    pll0_250MHz,
                        // Next comes all the S100 bus signals
    s100_n_RESET,       // on SBC board reset button (GPIOT_RXP12)
                        // Some of the SBC non-S100 output signals

    seg7,
    seg7_dp,
    usbTXbusyLED,
    usbRXbusyLED,
    usbRX,
    usbTXData,
    usbCTS
//    usbDTR,   //////////////////////////////////////////////////////////////////////////////////////
    
);
        
    input   clockIn;
    input   pll0_LOCKED;
    input   pll0_2MHz;
    input   pll0_50MHz;
    input   pll0_250MHz;
    input   usbRX;
    input   s100_n_RESET;
 //   input   usbDTR;                 //////////////////////////////////////////////////////////////////////////////////////

    output  [6:0] seg7;
    output  seg7_dp;

    output  usbTXbusyLED;
    output  usbRXbusyLED;
    output  usbTXData;
    output  usbCTS;
    


    wire    [7:0]   usbStat;        // USB UART Input Status port
    wire    [7:0]   usbRxData;      // USB UART received data
    wire    [7:0]   usbTxData;      // USB UART Transmit Data
    wire    [7:0]   usbTxDelay;
    //wire    n_reset;
    //wire    n_resetLatch;
    
////////////////////////////////////////////////////////////////////////////////////
    
    wire    usbDataReady;
    wire    usbUARTbusy;
    wire    usbByteRcvd;
    wire    usbBusyRcvg;
    wire    usbUARTOvrun;
    wire    usbUARTerror;
    wire    usbUARTFFull;
    wire    usbOverrun;

//////////////////////////////////////  MISC TESTING/DEBUG STUFF    ///////////////////////////////////////////////////////////////////////////////

reg [20:0]  counter;
reg [15:0]  reset_ctr = 0;
reg         sys_reset = 1'b0;

always @(posedge pll0_50MHz)
begin
    if ((!s100_n_RESET) | (!pll0_LOCKED))
    begin
        reset_ctr <= 0;
        sys_reset <= 1'b1;
    end
    else if (reset_ctr <= RESET_DELAY)
        reset_ctr <= reset_ctr + 1;
    else
    begin
        reset_ctr <= reset_ctr;
        sys_reset <= 1'b0;
    end
end




assign boardActive = !usbOverrun;       //!pll0_LOCKED;   // LED is LOW to turn ON

//assign n_reset = s100_n_RESET;
//assign seg7 = 7'b0001110;               // The letter "F", Top segment is LSB
assign seg7 [0] = !rxtx_state [0];
assign seg7 [1] = !rxtx_state [1];
assign seg7 [2] = !rxtx_state [2];
assign seg7 [3] = !usbDataReady;
assign seg7 [4] = !(!s100_n_RESET | !pll0_LOCKED);      //!usbUARTFFull;
assign seg7 [5] = sys_reset;
assign seg7 [6] = usbRX;

assign seg7_dp = !sec_flash;         // To show Overrun
assign diagLED = !usbUARTerror;        // s100_n_INT;       //1'b1;

assign usbRXbusyLED = !usbByteRcvd;
assign usbTXbusyLED = !usbUARTbusy;
assign usbCTS       = 1'b1;

/********************************************************************************
*       USB Status Register                                                     *
********************************************************************************/
assign usbStat[0] = usbDataReady;   // USB UART Data Ready      JOHN CONIN 
assign usbStat[1] = usbUARTbusy;    // USB UART Tx busy         JOHN CONOUT
assign usbStat[2] = usbByteRcvd;    // USB UART byte received
assign usbStat[3] = usbBusyRcvg;    // USB UART busy receiving
assign usbStat[4] = 1'b0;
assign usbStat[5] = usbUARTFFull;   // USB UART FIFO Full
assign usbStat[6] = usbUARTOvrun;   // USB UART Overrun...cleared by read
assign usbStat[7] = sec_flash;      // USB UART receive error
//assign usbRXbusyLED = !usbByteRcvd;
//assign usbTXbusyLED = !usbUARTbusy;
//assign usbCTS       = 1'b1;

parameter WAIT_RECV     = 0;
parameter READ_START    = 1;
parameter READ_END      = 2;
parameter WAIT_TXE      = 3;
parameter WRITE_TX      = 4;
parameter TICK_VALUE    = 50000000;
parameter FLASH_VALUE   = 25000000;
parameter RESET_DELAY   = 50000;

//parameter TICK_VALUE    = 10000;

reg [2:0]   rxtx_state; 
reg [2:0]   rxtx_state_next;
reg [7:0]   uart_data;              // Holding Byte for received data loopback
wire        tx_enable;
wire        rx_enable;
wire        rd_data_en;

reg [31:0]  tick_count;
wire        sec_flash;

assign sec_flash = (tick_count > FLASH_VALUE) ? 1'b1 : 1'b0;

always @(posedge pll0_50MHz)
begin
    if ((sys_reset) | (tick_count >= TICK_VALUE))
        tick_count <= 0;
    else
        tick_count <= tick_count + 1;
end

//assign rxtx_clock_en = (tick_count == TICK_VALUE) ? 1'b1 : 1'b0;

always @(posedge pll0_50MHz)
begin
    // ****************************************************
    // * Handle Read/Write State Machine
    // ****************************************************
 	// if (rxtx_clock_en)
    begin
        if (sys_reset)
            rxtx_state  <= WAIT_RECV;
        else 
            rxtx_state  <= rxtx_state_next;
    end
    
    begin
        if (rd_data_en)
            uart_data <= usbRxData;
        else
            uart_data <= uart_data;
    end
end

always @(rxtx_state or usbUARTFFull or usbDataReady or usbUARTbusy)
begin
    case (rxtx_state)
        WAIT_RECV   : if (usbUARTFFull)         rxtx_state_next = READ_START;
                      else                      rxtx_state_next = WAIT_RECV;
        READ_START  :                           rxtx_state_next = READ_END;
        READ_END    : if (usbDataReady)         rxtx_state_next = WAIT_TXE;
                      else                      rxtx_state_next = WAIT_RECV;
        WAIT_TXE    : if (usbUARTbusy)          rxtx_state_next = WAIT_TXE;
                      else                      rxtx_state_next = WRITE_TX;
        WRITE_TX    : if (usbDataReady)         rxtx_state_next = READ_START;
                      else                      rxtx_state_next = WAIT_RECV;
        default                                 rxtx_state_next = WAIT_RECV;
    endcase
end

// rxtx_state State Machine combinatorial enables
assign rd_data_en   =  ((rxtx_state == READ_START) | 
                        (rxtx_state == READ_END))       ? 1'b1 : 1'b0;
assign tx_enable    =   (rxtx_state == WRITE_TX)        ? 1'b1 : 1'b0;
assign rx_enable    =   (rxtx_state == READ_START)      ? 1'b1 : 1'b0;


/****************************************************************************
*       USB UART serial data transfer                                       *
*           From opencores                                                  *
****************************************************************************/
uart  usbuart(
    .clk                (pll0_50MHz),		// The master clock for this module 50MHz
    .rst                (sys_reset),        // Synchronous reset.
    .rx 				(usbRX),		    // UART Input - Incoming serial line
    .txd_out			(usbTXData),	    // UART output - Outgoing serial line
    .transmit 			(tx_enable),        // Input to UART - Signal to transmit a byte = 1
    .tx_byte 		    (uart_data),        // UART input - Byte to transmit
    .received 			(usbByteRcvd),      // UART output - Indicates a byte has been rcvd
    .rcvd_byte 		    (usbRxData),        // UART OUTPUT - Byte received
    .is_receiving 		(usbBusyRcvg),      // UART output Low when receive line is idle.
    .is_transmitting 	(usbUARTbusy),      // UART output - Low when transmit line is idle.
    .recv_error         (usbUARTerror),     // output - Indicates error in receiving data.
	.data_ready         (usbDataReady),     // UART Output - has Rx data
	.data_read          (rx_enable),        // UART input - read the received data
    .rcvr_overrun       (usbUARTOvrun),     // UART Character Overrun
    .rcvr_fifo_full     (usbUARTFFull));    // UART FIFO Full

endmodule 
