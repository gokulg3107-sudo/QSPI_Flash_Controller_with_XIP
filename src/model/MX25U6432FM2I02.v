////////////////////////////////////////////////////////////////////////////////
//                       MX25U6432FM2I02.v                                    //
//          Behavioral Verilog Model for MX25U6432FM2I02                      //
//             64-Mibit CMOS Serial NOR Flash Memory                          //
//                                                                            //
//            Module Name: MX25U6432FM2I02                                    //
//           Package Type: 8-SOP(200mil)                                      //
//       Tested Simulator: Cadence NC-Verilog                                 //
//    Datasheet Reference: MX25U6432F                                         //
//                         Rev. 1.0, November 01, 2019                        //
//    Model Creation Date: March 12, 2020                                     //
//         Security Level: Macronix Proprietary                               //
//                   $GIT: 593731de9dfaeb58775a2e67411d2511c471d7d9 $         //
//                                                                            //
//      (c) COPYRIGHT 2020 Macronix International Co., Ltd.                   //
////////////////////////////////////////////////////////////////////////////////
// Notes:                                                                     //
//                                                                            //
// (1) Flash data are initialized to all 0xFF by default, and                 //
//     Init_File_* macros are defined as "none" to disable pre-loading.       //
//     To enable pre-loading, please change them to proper filenames.         //
//                                                                            //
//     For example, values in "my_init_file" will be loaded into the          //
//     main-region of the flash by the following setting.                     //
//                                                                            //
//     `define Init_File_MAIN "my_init_file"                                  //
//                                                                            //
// (2) SFDP data are also initialized to all 0xFF by default. For detailed    //
//     SFDP information, please contact with Macronix.                        //
//                                                                            //
// (3) This model does not accept commands until tVSL is satisfied. Please    //
//     send the first command after 800 microseconds.                         //
//                                                                            //
// (4) This model does not insert tCLQX timing for the read-commands because  //
//     currently board-system simulation effect is not checked.               //
//                                                                            //
// (5) Corner values (i.e., Min., Typ. and Max.) are defined for some AC      //
//     parameters in the datasheet. However, only one of them is selected in  //
//     this behavioral model. For example, Typ. tPP (400 us) is used in       //
//     this model as Page Program cycle time. For more detailed information   //
//     of these AC parameters, please refer to the datasheet or contact with  //
//     Macronix.                                                              //
//                                                                            //
// (6) If you have any questions and suggestions, please send your e-mail to: //
//                    flash_model@mxic.com.tw                                 //
////////////////////////////////////////////////////////////////////////////////

//////////////////// Begin of `define block user may change ////////////////////
`define LOADING_15PF	// Output Loading 15pF
//`define LOADING_30PF	// Output Loading 30pF
`define Init_File_MAIN "none" // Filename for loading MAIN data
`define Init_File_SOTP "none"
`define Init_File_SFDP "none"
//////////////////// End of `define block user may change //////////////////////

`timescale 1ns/100ps

`define bitsCOMD    8 // bit-size for COMD
`define bitsADDR   24 // bit-size for ADDR
`define bitsAD3B   24 // bit-size for AD3B
`define bitsAD4B   32 // bit-size for AD4B
`define bitsMAIN   23 // bit-size for MAIN
`define bitsARRY   24 // bit-size for mxArray
`define bitsBYTE    8 // bit-size for BYTE
`define bitsPHAS   16 // bit-size for PHAS
`define bitsDATA    8 // bit-size for DATA
`define bitsSECT   12 // bit-size for SECT
`define bitsB32K   15 // bit-size for B32K
`define bitsBLOK   16 // bit-size for BLOK
`define bitsTHRD    2 // bit-size for THRD

`define sizeDATA       256 // size for DATA
`define sizeSECT      4096 // size for SECT
`define sizeB32K     32768 // size for B32K
`define sizeBLOK     65536 // size for BLOK
`define sizeTHRD         4 // size for THRD
`define sizeMAIN   8388608 // size for MAIN
`define sizeSOTP      1024 // size for SOTP
`define sizeSFDP       512 // size for SFDP
`define sizeRDID         3 // size for RDID
`define sizeREMS         2 // size for REMS
`define sizeSREG         1 // size for SREG
`define sizeSRDEF        1 // size for SRDEF
`define sizeSRMSK        1 // size for SRMSK
`define sizeSROTP        1 // size for SROTP
`define sizeSRVOL        1 // size for SRVOL
`define sizeCREG         1 // size for CREG
`define sizeCRDEF        1 // size for CRDEF
`define sizeCRMSK        1 // size for CRMSK
`define sizeCROTP        1 // size for CROTP
`define sizeCRVOL        1 // size for CRVOL
`define sizeSCUR         1 // size for SCUR
`define sizeSCDEF        1 // size for SCDEF
`define sizeSCMSK        1 // size for SCMSK
`define sizeSCOTP        1 // size for SCOTP
`define sizeSCVOL        1 // size for SCVOL
`define sizeLREG         2 // size for LREG
`define sizeLRDEF        2 // size for LRDEF
`define sizeLRMSK        2 // size for LRMSK
`define sizeLROTP        2 // size for LROTP
`define sizeLRVOL        2 // size for LRVOL
`define sizeSBLR         1 // size for SBLR
`define sizeSPBR       158 // size for SPBR
`define sizeDPBR       158 // size for DPBR
`define sizeFMSR         1 // size for FMSR
`define sizeINTF         1 // size for INTF
`define sizeITFDEF       1 // size for ITFDEF
`define sizeMODE         1 // size for MODE
`define unit_ms 1_000_000
`define lensCOMD 72

module MX25U6432FM2I02 (SCLK, CS, SI, SO, WP, SIO3);
	input SCLK; // Serial Clock Input
	input CS;  // Chip Select (low active)
	inout SI;  // Serial Input/Output SIO0
	inout SO;  // Serial Input/Output SIO1
	inout WP;  // Serial Input/Output SIO2/WP=1
	inout SIO3; // Serial Input/Output SIO3/RESET=1

	parameter msbDC04   =  3;
	parameter msbDC06   =  5;
	parameter msbDC08   =  7;
	parameter msbDC10   =  9;
	parameter fCLK066   =  66, tCLK066   = 15.2;
	parameter fCLK084   =  84, tCLK084   = 11.9;
	parameter fCLK104   = 104, tCLK104   =  9.6;
	parameter fCLK133   = 133, tCLK133   =  7.5;
	parameter msbCOMD   = `bitsCOMD   - 1, lsbCOMD   = 0;
	parameter msbADDR   = `bitsADDR   - 1, lsbADDR   = 0;
	parameter msbAD3B   = `bitsAD3B   - 1, lsbAD3B   = 0;
	parameter msbAD4B   = `bitsAD4B   - 1, lsbAD4B   = 0;
	parameter msbMAIN   = `bitsMAIN   - 1, lsbMAIN   = 0;
	parameter msbARRY   = `bitsARRY   - 1, lsbARRY   = 0;
	parameter msbBYTE   = `bitsBYTE   - 1, lsbBYTE   = 0;
	parameter msbDATA   = `bitsDATA   - 1, lsbDATA   = 0;
	parameter msbSECT   = `bitsSECT   - 1, lsbSECT   = 0;
	parameter msbB32K   = `bitsB32K   - 1, lsbB32K   = 0;
	parameter msbBLOK   = `bitsBLOK   - 1, lsbBLOK   = 0;
	parameter msbTHRD   = `bitsTHRD   - 1, lsbTHRD   = 0;

	parameter oriDATA   = `bitsDATA'h00,      endDATA   = `bitsDATA'hFF;
	parameter oriSECT   = `bitsSECT'h000,     endSECT   = `bitsSECT'hFFF;
	parameter oriB32K   = `bitsB32K'h0000,    endB32K   = `bitsB32K'h7FFF;
	parameter oriBLOK   = `bitsBLOK'h0000,    endBLOK   = `bitsBLOK'hFFFF;
	parameter oriTHRD   = `bitsTHRD'h0,       endTHRD   = `bitsTHRD'h3;
	parameter oriMAIN   = `bitsARRY'h00_0000, endMAIN   = `bitsARRY'h7F_FFFF;
	parameter oriSOTP   = `bitsARRY'h80_0000, endSOTP   = `bitsARRY'h80_03FF;
	parameter oriSFDP   = `bitsARRY'h80_0400, endSFDP   = `bitsARRY'h80_05FF;
	parameter oriRDID   = `bitsARRY'h80_0600, endRDID   = `bitsARRY'h80_0602;
	parameter oriREMS   = `bitsARRY'h80_0603, endREMS   = `bitsARRY'h80_0604;
	parameter oriSREG   = `bitsARRY'h80_0605, endSREG   = `bitsARRY'h80_0605;
	parameter oriSRDEF  = `bitsARRY'h80_0606, endSRDEF  = `bitsARRY'h80_0606;
	parameter oriSRMSK  = `bitsARRY'h80_0607, endSRMSK  = `bitsARRY'h80_0607;
	parameter oriSROTP  = `bitsARRY'h80_0608, endSROTP  = `bitsARRY'h80_0608;
	parameter oriSRVOL  = `bitsARRY'h80_0609, endSRVOL  = `bitsARRY'h80_0609;
	parameter oriCREG   = `bitsARRY'h80_060A, endCREG   = `bitsARRY'h80_060A;
	parameter oriCRDEF  = `bitsARRY'h80_060B, endCRDEF  = `bitsARRY'h80_060B;
	parameter oriCRMSK  = `bitsARRY'h80_060C, endCRMSK  = `bitsARRY'h80_060C;
	parameter oriCROTP  = `bitsARRY'h80_060D, endCROTP  = `bitsARRY'h80_060D;
	parameter oriCRVOL  = `bitsARRY'h80_060E, endCRVOL  = `bitsARRY'h80_060E;
	parameter oriSCUR   = `bitsARRY'h80_060F, endSCUR   = `bitsARRY'h80_060F;
	parameter oriSCDEF  = `bitsARRY'h80_0610, endSCDEF  = `bitsARRY'h80_0610;
	parameter oriSCMSK  = `bitsARRY'h80_0611, endSCMSK  = `bitsARRY'h80_0611;
	parameter oriSCOTP  = `bitsARRY'h80_0612, endSCOTP  = `bitsARRY'h80_0612;
	parameter oriSCVOL  = `bitsARRY'h80_0613, endSCVOL  = `bitsARRY'h80_0613;
	parameter oriLREG   = `bitsARRY'h80_0614, endLREG   = `bitsARRY'h80_0615;
	parameter oriLRDEF  = `bitsARRY'h80_0616, endLRDEF  = `bitsARRY'h80_0617;
	parameter oriLRMSK  = `bitsARRY'h80_0618, endLRMSK  = `bitsARRY'h80_0619;
	parameter oriLROTP  = `bitsARRY'h80_061A, endLROTP  = `bitsARRY'h80_061B;
	parameter oriLRVOL  = `bitsARRY'h80_061C, endLRVOL  = `bitsARRY'h80_061D;
	parameter oriSBLR   = `bitsARRY'h80_061E, endSBLR   = `bitsARRY'h80_061E;
	parameter oriSPBR   = `bitsARRY'h80_061F, endSPBR   = `bitsARRY'h80_06BC;
	parameter oriDPBR   = `bitsARRY'h80_06BD, endDPBR   = `bitsARRY'h80_075A;
	parameter oriFMSR   = `bitsARRY'h80_075B, endFMSR   = `bitsARRY'h80_075B;
	parameter oriINTF   = `bitsARRY'h80_075C, endINTF   = `bitsARRY'h80_075C;
	parameter oriITFDEF = `bitsARRY'h80_075D, endITFDEF = `bitsARRY'h80_075D;
	parameter oriMODE   = `bitsARRY'h80_075E, endMODE   = `bitsARRY'h80_075E;

	parameter inifMAIN = `Init_File_MAIN; // load MAIN data
	parameter inifSOTP = `Init_File_SOTP; // load SOTP data
	parameter inifSFDP = `Init_File_SFDP; // load SFDP data

	parameter cmdREAD     = `bitsCOMD'h03;
	parameter cmdFASTREAD = `bitsCOMD'h0B;
	parameter cmd2READ    = `bitsCOMD'hBB;
	parameter cmdDREAD    = `bitsCOMD'h3B;
	parameter cmd4READ    = `bitsCOMD'hEB;
	parameter cmdQREAD    = `bitsCOMD'h6B;
	parameter cmdW4READ   = `bitsCOMD'hE7;
	parameter cmdPP       = `bitsCOMD'h02;
	parameter cmd4PP      = `bitsCOMD'h38;
	parameter cmdSE       = `bitsCOMD'h20;
	parameter cmdBE32K    = `bitsCOMD'h52;
	parameter cmdBE       = `bitsCOMD'hD8;
	parameter cmdCE_1     = `bitsCOMD'h60;
	parameter cmdCE_2     = `bitsCOMD'hC7;
	parameter cmdWREN     = `bitsCOMD'h06;
	parameter cmdWRDI     = `bitsCOMD'h04;
	parameter cmdWPSEL    = `bitsCOMD'h68;
	parameter cmdEQIO     = `bitsCOMD'h35;
	parameter cmdRSTQIO   = `bitsCOMD'hF5;
	parameter cmdSUS_2    = `bitsCOMD'h75;
	parameter cmdSUS_1    = `bitsCOMD'hB0;
	parameter cmdRSM_2    = `bitsCOMD'h7A;
	parameter cmdRSM_1    = `bitsCOMD'h30;
	parameter cmdDP       = `bitsCOMD'hB9;
	parameter cmdNOP      = `bitsCOMD'h00;
	parameter cmdRSTEN    = `bitsCOMD'h66;
	parameter cmdRST      = `bitsCOMD'h99;
	parameter cmdGBLK     = `bitsCOMD'h7E;
	parameter cmdGBULK    = `bitsCOMD'h98;
	parameter cmdFMEN     = `bitsCOMD'h41;
	parameter cmdRDID     = `bitsCOMD'h9F;
	parameter cmdRES      = `bitsCOMD'hAB;
	parameter cmdREMS     = `bitsCOMD'h90;
	parameter cmdQPIID    = `bitsCOMD'hAF;
	parameter cmdRDSFDP   = `bitsCOMD'h5A;
	parameter cmdRDSR     = `bitsCOMD'h05;
	parameter cmdRDCR     = `bitsCOMD'h15;
	parameter cmdRDFMSR   = `bitsCOMD'h44;
	parameter cmdWRSR     = `bitsCOMD'h01;
	parameter cmdRDSCUR   = `bitsCOMD'h2B;
	parameter cmdWRSCUR   = `bitsCOMD'h2F;
	parameter cmdSBL      = `bitsCOMD'hC0;
	parameter cmdENSO     = `bitsCOMD'hB1;
	parameter cmdEXSO     = `bitsCOMD'hC1;
	parameter cmdWRLR     = `bitsCOMD'h2C;
	parameter cmdRDLR     = `bitsCOMD'h2D;
	parameter cmdWRSPB    = `bitsCOMD'hE3;
	parameter cmdESSPB    = `bitsCOMD'hE4;
	parameter cmdRDSPB    = `bitsCOMD'hE2;
	parameter cmdWRDPB    = `bitsCOMD'hE1;
	parameter cmdRDDPB    = `bitsCOMD'hE0;

	specify
`ifdef LOADING_15PF
		specparam tCLQV      =              6;
`elsif LOADING_30PF
		specparam tCLQV      =              8;
`endif
		specparam fSCLK      =            133;
		specparam tSCLK      =            7.5;
		specparam fRSCLK     =             50;
		specparam tRSCLK     =             20;
		specparam tCH        = 0.45*(1/fSCLK);
		specparam tCH_R      =              7;
		specparam tCL        = 0.45*(1/fSCLK);
		specparam tCL_R      =              7;
		specparam tSLCH      =              5;
		specparam tCHSL      =              5;
		specparam tDVCH      =              2;
		specparam tCHDX      =              3;
		specparam tCHSH      =              5;
		specparam tSHCH      =              5;
		specparam tSHSL_R    =              7;
		specparam tSHSL_W    =             30;
		specparam tSHQZ      =              8;
		specparam tWHSL      =             20;
		specparam tSHWL      =            100;
		specparam tDP        =         10_000;
		specparam tDPDD      =         30_000;
		specparam tCRDP      =             20;
		specparam tRDP       =         30_000;
		specparam tW         =     40_000_000;
		specparam tBP        =         18_000;
		specparam tPP        =        400_000;
		specparam tSE        =     30_000_000;
		specparam tBE32      =    150_000_000;
		specparam tBE        =    300_000_000;
		specparam tCE_ms     =         18_000;
		specparam tESL       =         25_000;
		specparam tPSL       =         25_000;
		specparam tPRS       =        100_000;
		specparam tERS       =        100_000;
		specparam tSE_FMD    =     15_000_000;
		specparam tBE32_FMD  =    100_000_000;
		specparam tBE_FMD    =    200_000_000;
		specparam tCE_FMD_ms =         13_000;
		specparam tPP_FMD    =        330_000;
		specparam tRHSL      =         10_000;
		specparam tRS        =             15;
		specparam tRH        =             15;
		specparam tRLRH      =         10_000;
		specparam tREADY2_D  =         40_000;
		specparam tREADY2_R  =         35_000;
		specparam tREADY2_P  =        310_000;
		specparam tREADY2_SE =     12_000_000;
		specparam tREADY2_BE =     25_000_000;
		specparam tREADY2_CE =    100_000_000;
		specparam tREADY2_W  =     40_000_000;
		specparam tVSL       =        800_000;
	endspecify

	// Interface
	parameter itfSPI = `bitsBYTE'b0000_0001;
	parameter itfMSK = `bitsBYTE'b0000_0011;
	parameter itfQPI = `bitsBYTE'b0000_0010;

	// Status Register
	parameter bitSRWD = 7;
	parameter bitQE = 6;
	parameter bitBP3 = 5, bitBP2 = 4, bitBP1 = 3, bitBP0 = 2;
	parameter bitWEL = 1, bitWIP = 0;

	// Configuration Register
	parameter bitTB = 3;
	parameter bitDC1 = 7;
	parameter bitDC0 = 6;

	// Security Register
	parameter bitWPSEL = 7;
	parameter tPGM_CHK = 2_000;
	parameter tERS_CHK = 100_000;
	parameter bitPFAIL = 5;
	parameter bitEFAIL = 6;
	parameter bitESB = 3, bitPSB = 2;
	parameter bitLDSO = 1, bitFLSO = 0;

	// Burst Length Register
	parameter mskSBLR = `bitsBYTE'b0001_0011;
	parameter mskWRAP = `bitsBYTE'b0001_0000;
	parameter lenSBLR = 8; // base burst length

	// DPB Register
	parameter mskDPBR = `bitsBYTE'b1111_1111;
	// SPB Register
	parameter mskSPBR = `bitsBYTE'b1111_1111;

	// Lock Register
	parameter bitSPBLKDN = 6; // Solid protect lock down

	// Mode Register
	parameter bitSOTP = 0;
	parameter bitDP   = 1;
	parameter bitPR2S = 3;
	parameter bitEHMD = 4;
	parameter bitRSTEN = 5;
	parameter bitDPDD = 6;

	parameter phsINIT = `bitsPHAS'h0000; // power up
	parameter phsIDLE = `bitsPHAS'h0001; // chip idle
	parameter phsEXE1 = `bitsPHAS'h0004; // write execution for bit
	parameter phsEXE8 = `bitsPHAS'h0005; // write execution for byte
	parameter phsEXEC = `bitsPHAS'h0006; // write execution for WIP
	parameter phsINTR = `bitsPHAS'h0007; // write execution for interupt commads
	parameter phsRDPM = `bitsPHAS'h0008; // release from DP mode
	parameter phsFAIL = `bitsPHAS'h000F; // command decode failure

	parameter phsCMD1 = `bitsPHAS'h0801; // 1-IO STR command input
	parameter phsADR1 = `bitsPHAS'h0401; // 1-IO STR address input
	parameter phsDMY1 = `bitsPHAS'h0201; // 1-IO STR dummy cycles
	parameter phsDIN1 = `bitsPHAS'h0101; // 1-IO STR data input
	parameter phsOUT1 = `bitsPHAS'h0011; // 1-IO STR data output
	parameter phm1XIO = `bitsPHAS'h0001; // 1-IO address dummy input mask
	parameter phsADR2 = `bitsPHAS'h0402; // 2-IO STR address input
	parameter phsDMY2 = `bitsPHAS'h0202; // 2-IO STR dummy cycles
	parameter phsDIN2 = `bitsPHAS'h0102; // 2-IO STR data input
	parameter phsOUT2 = `bitsPHAS'h0012; // 2-IO STR data output
	parameter phm2XIO = `bitsPHAS'h0002; // 2-IO address dummy input mask

	parameter phsCMD4 = `bitsPHAS'h0804; // 4-IO STR command input
	parameter phsADR4 = `bitsPHAS'h0404; // 4-IO STR address input
	parameter phsDMY4 = `bitsPHAS'h0204; // 4-IO STR dummy cycles
	parameter phsDIN4 = `bitsPHAS'h0104; // 4-IO STR data input
	parameter phsOUT4 = `bitsPHAS'h0014; // 4-IO STR data output
	parameter phm4XIO = `bitsPHAS'h0004; // 4-IO address dummy input mask
	parameter phmINP  = `bitsPHAS'h0D00; // DIN
	parameter phmOUT  = `bitsPHAS'h0010; // OUT
	parameter phmDTR  = `bitsPHAS'h1000; // DTR
	parameter phmDMY  = `bitsPHAS'h0200; // DUMMY
	parameter phmADI  = `bitsPHAS'h0700; // Address, Dummy, DIN
	parameter phmADIO = `bitsPHAS'h0710; // Address, Dummy, DIN, DOUT

	integer i, iBit;
	integer iIndex, iRange;
	integer iPhase, iClock;
	integer iEvent;
	integer iSkips;
	integer  dcArray[0:2][0:3];
	realtime fcArray[0:3][0:3];
	realtime tcArray[0:3][0:3];
	reg [msbBYTE:lsbBYTE] mxArray [oriMAIN:endMODE];

	wire inSCLK;    assign inSCLK    = SCLK;
	wire inCS_b;    assign inCS_b    = CS;
	wire inSIO0;    assign inSIO0    = SI;
	wire inSIO1;    assign inSIO1    = SO;
	wire inSIO2;    assign inSIO2    = WP;
	wire inWP_b;    assign inWP_b    = WP;
	wire inSIO3;    assign inSIO3    = SIO3;
	wire inRESET_b; assign inRESET_b = SIO3;
	reg outSIO0;    assign SI        = outSIO0;
	reg outSIO1;    assign SO        = outSIO1;
	reg outSIO2;    assign WP        = outSIO2;
	reg outSIO3;    assign SIO3      = outSIO3;

	integer iThd;
	integer thdLen [1:`sizeTHRD];
	time thdTOUT [1:`sizeTHRD];
	time thdTSUS [1:`sizeTHRD];
	reg thdTRIG;
	reg thdWIP [1:`sizeTHRD];
	reg thdPRE [1:`sizeTHRD];
	reg [msbCOMD:lsbCOMD] regCOMD [1:`sizeTHRD];
	reg [msbADDR:lsbADDR] regADDR [1:`sizeTHRD];
	reg [msbBYTE:lsbBYTE] regDUMY [1:`sizeTHRD];
	reg [msbBYTE:lsbBYTE] regDATA [1:`sizeTHRD] [oriDATA:endDATA];
	reg [msbARRY:lsbARRY] regAOUT;
	reg [msbBYTE:lsbBYTE] regEHIN, regEHMD;
	integer iEhidx;
	reg [`lensCOMD:1] strCOMD;
	reg tcSHSL_R, tcSHSL_W;
	realtime falCS, risCS, falSCLK, risSCLK;
	realtime tcSCLK, fcSCLK;

	event e_thread_trigger;

	// Signal assign
	wire [msbBYTE:lsbBYTE] INTF;
	assign INTF    = mxArray[oriINTF];
	assign SPI     = INTF == itfSPI ? 1 : 0;
	assign QPI     = INTF == itfQPI ? 1 : 0;
	assign SRWD    = mxArray[oriSREG][bitSRWD];
	assign WEL     = mxArray[oriSREG][bitWEL];
	assign WIP     = mxArray[oriSREG][bitWIP];
	assign QE      = mxArray[oriSREG][bitQE];
	assign TB      = mxArray[oriCREG][bitTB];
	assign PR2S    = mxArray[oriMODE][bitPR2S];
	assign PSUS    = mxArray[oriSCUR][bitPSB];
	assign ESUS    = mxArray[oriSCUR][bitESB];
	assign WPSEL   = mxArray[oriSCUR][bitWPSEL];
	assign SPBLK   = ~mxArray[oriLREG][bitSPBLKDN];
	assign FLSO    = mxArray[oriSCUR][bitFLSO];
	assign LDSO    = mxArray[oriSCUR][bitLDSO];
	assign ENWP    = (INTF != itfQPI && QE == 0) ? 1 : 0;
	assign ENRESET = (INTF != itfQPI && QE == 0) ? 1 : 0;
	assign DP     = mxArray[oriMODE][bitDP];
	reg tcDP;
	assign DPDD   = mxArray[oriMODE][bitDPDD];
	assign SOTP   = mxArray[oriMODE][bitSOTP];
	assign RSTEN  = mxArray[oriMODE][bitRSTEN];
	assign FMD    = mxArray[oriFMSR] == `bitsBYTE'hFF ? 1 : 0;
	assign EHMD   = mxArray[oriMODE][bitEHMD];
	assign tcIN   = (iPhase & phmINP) ? 1 : 0;
	assign tcREAD = ~inCS_b && (iPhase & phmADIO)
	       && (regCOMD[iThd] == cmdREAD) ? 1 : 0;

	reg [msbARRY:lsbARRY] WPSEL_limit[0:2];
	integer WPSEL_shift[0:2], WPSEL_delta[0:2];

	initial begin: offset_init
		WPSEL_limit[0] = 'h01_0000; WPSEL_shift[0] = `bitsSECT; WPSEL_delta[0] = 0;
		WPSEL_limit[1] = 'h7f_0000; WPSEL_shift[1] = `bitsBLOK; WPSEL_delta[1] = 16;
		WPSEL_limit[2] = 'h80_0000; WPSEL_shift[2] = `bitsSECT; WPSEL_delta[2] = 142;
	end

	initial begin: memory_init
		for (i = oriMAIN;   i <= endMAIN;   i = i + 1) mxArray[i] = `bitsBYTE'hFF;
		for (i = oriSOTP;   i <= endSOTP;   i = i + 1) mxArray[i] = `bitsBYTE'hFF;
		for (i = oriSFDP;   i <= endSFDP;   i = i + 1) mxArray[i] = `bitsBYTE'hFF;

		i = oriRDID;   mxArray[i] = `bitsBYTE'hC2; // Manufacturer
		i = i + 1;     mxArray[i] = `bitsBYTE'h25; // Memory Type
		i = i + 1;     mxArray[i] = `bitsBYTE'h37; // Memory Density

		i = oriREMS;   mxArray[i] = `bitsBYTE'hC2; // Manufacturer
		i = i + 1;     mxArray[i] = `bitsBYTE'h37; // Device ID

		mxArray[oriSREG  ] = `bitsBYTE'h00;
		mxArray[oriSRDEF ] = `bitsBYTE'h00;
		mxArray[oriSRMSK ] = `bitsBYTE'hFC;
		mxArray[oriSROTP ] = `bitsBYTE'h00;
		mxArray[oriSRVOL ] = `bitsBYTE'h03;
		mxArray[oriCREG  ] = `bitsBYTE'h07;
		mxArray[oriCRDEF ] = `bitsBYTE'h07;
		mxArray[oriCRMSK ] = `bitsBYTE'hCF;
		mxArray[oriCROTP ] = `bitsBYTE'h08;
		mxArray[oriCRVOL ] = `bitsBYTE'hC7;
		mxArray[oriSCUR  ] = `bitsBYTE'h00;
		mxArray[oriSCDEF ] = `bitsBYTE'h00;
		mxArray[oriSCMSK ] = `bitsBYTE'h02;
		mxArray[oriSCOTP ] = `bitsBYTE'h83;
		mxArray[oriSCVOL ] = `bitsBYTE'h7C;

		i = oriLREG;   mxArray[i] = `bitsBYTE'hFF;
		i = i + 1;     mxArray[i] = `bitsBYTE'hFF;

		i = oriLRDEF;  mxArray[i] = `bitsBYTE'hFF;
		i = i + 1;     mxArray[i] = `bitsBYTE'hFF;

		i = oriLRMSK;  mxArray[i] = `bitsBYTE'h40;
		i = i + 1;     mxArray[i] = `bitsBYTE'h00;

		i = oriLROTP;  mxArray[i] = `bitsBYTE'hFF;
		i = i + 1;     mxArray[i] = `bitsBYTE'hFF;

		i = oriLRVOL;  mxArray[i] = `bitsBYTE'h00;
		i = i + 1;     mxArray[i] = `bitsBYTE'h00;
		mxArray[oriSBLR  ] = `bitsBYTE'hFF;
		for (i = oriSPBR;   i <= endSPBR;   i = i + 1) mxArray[i] = `bitsBYTE'h00;
		for (i = oriDPBR;   i <= endDPBR;   i = i + 1) mxArray[i] = `bitsBYTE'hFF;
		mxArray[oriFMSR  ] = `bitsBYTE'h00;
		mxArray[oriINTF  ] = `bitsBYTE'h01;
		mxArray[oriITFDEF] = `bitsBYTE'h01;
		mxArray[oriMODE  ] = `bitsBYTE'h00;

		system_reset;

		if (inifMAIN != "none") $readmemh (inifMAIN, mxArray, oriMAIN, endMAIN);
		if (inifSOTP != "none") $readmemh (inifSOTP, mxArray, oriSOTP, endSOTP);
		if (inifSFDP != "none") $readmemh (inifSFDP, mxArray, oriSFDP, endSFDP);
	end

	initial begin: dummy_init
		dcArray[0][0] = msbDC08;
		dcArray[0][1] = msbDC06;
		dcArray[0][2] = msbDC08;
		dcArray[0][3] = msbDC10;
		dcArray[1][0] = msbDC04;
		dcArray[1][1] = msbDC06;
		dcArray[1][2] = msbDC08;
		dcArray[1][3] = msbDC10;
		dcArray[2][0] = msbDC06;
		dcArray[2][1] = msbDC04;
		dcArray[2][2] = msbDC08;
		dcArray[2][3] = msbDC10;
		fcArray[0][0] = fCLK104; tcArray[0][0] = tCLK104;
		fcArray[0][1] = fCLK104; tcArray[0][1] = tCLK104;
		fcArray[0][2] = fCLK104; tcArray[0][2] = tCLK104;
		fcArray[0][3] = fCLK133; tcArray[0][3] = tCLK133;
		fcArray[1][0] = fCLK084; tcArray[1][0] = tCLK084;
		fcArray[1][1] = fCLK104; tcArray[1][1] = tCLK104;
		fcArray[1][2] = fCLK104; tcArray[1][2] = tCLK104;
		fcArray[1][3] = fCLK133; tcArray[1][3] = tCLK133;
		fcArray[2][0] = fCLK084; tcArray[2][0] = tCLK084;
		fcArray[2][1] = fCLK066; tcArray[2][1] = tCLK066;
		fcArray[2][2] = fCLK104; tcArray[2][2] = tCLK104;
		fcArray[2][3] = fCLK133; tcArray[2][3] = tCLK133;
		fcArray[3][0] = fCLK104; tcArray[3][0] = tCLK104;
		fcArray[3][1] = fCLK084; tcArray[3][1] = tCLK084;
		fcArray[3][2] = fCLK104; tcArray[3][2] = tCLK104;
		fcArray[3][3] = fCLK133; tcArray[3][3] = tCLK133;
	end

	initial begin
		iIndex = 0;
		iRange = 0;
		iPhase = phsINIT;
		iEvent = phsIDLE;
		iPhase <= #tVSL phsIDLE; // power up

		outSIO0 <= 1'bz;
		outSIO1 <= 1'bz;
		outSIO2 <= 1'bz;
		outSIO3 <= 1'bz;
	end

	// CS_b falling
	always @(negedge inCS_b) begin
		falCS = $time;
		if ((falCS - risCS) < tSHSL_W && tcSHSL_W == 1) tshsl_cancel(iThd);
		tcSHSL_R = 0; tcSHSL_W = 0;
		fcSCLK = fSCLK; tcSCLK = tSCLK;
		if (iPhase == phsINIT) begin
			$display ("*ERROR* COMMAND is inhibited during power-up or reset phase");
		end
		else begin
			iBit = `bitsBYTE; thdLen[iThd] = 0; iClock = 0;
			iEvent = phsIDLE;
			strCOMD = "-";

			iEhidx = 0; regEHIN = `bitsBYTE'h0;
			if (EHMD) begin
				case (regEHMD)
					cmd4READ: begin
						iIndex = msbADDR;
						iSkips = 0; iPhase = phsADR4;
					end
				endcase
				iRange = lsbADDR; iEhidx = msbCOMD;
			end
			else begin
				iIndex = msbCOMD;
				iRange = lsbCOMD;
				iPhase = QPI == 1 ? phsCMD4 : phsCMD1;
			end
		end
	end

	// CS_b rising
	always @(posedge inCS_b) begin
		risCS = $time;
		if (iPhase & phmOUT) tcSHSL_R = 1;
		else tcSHSL_W = 1;
		if (DP == 1 && DPDD == 0 && (risCS - falCS >= tCRDP)) dp_released;
		if (EHMD == 1) begin
			case (regEHIN)
				cmdRST:   if (RSTEN == 1) during_reset;
				cmdRSTEN: bit_write(oriMODE, bitRSTEN, 1);
			endcase
		end
		if (iEvent != phsIDLE && iPhase != phsFAIL) begin
			if ((iBit % `bitsBYTE) == 0) begin
				case (iEvent)
					phsEXE1: write_exec_bit;
					phsEXE8: if (WIP == 0) write_exec_byte;
					phsEXEC: if (WIP == 0) write_exec_wip;
					phsINTR: write_exec_intr;
				endcase
			end
			else iPhase = phsFAIL;
		end
		if (iPhase != phsINIT) iPhase = phsIDLE;
		outSIO0 <= #tSHQZ 1'bz;
		outSIO1 <= #tSHQZ 1'bz;
		outSIO2 <= #tSHQZ 1'bz;
		outSIO3 <= #tSHQZ 1'bz;
	end

	// while thread WIP event trigger
	always @(posedge thdTRIG) begin
		->e_thread_trigger;
		for (i = 1; i <= `sizeTHRD; i = i + 1) begin
			if (thdTOUT[i] <= $time && thdTSUS[i] == 0) begin
				thd_wip_exec(i);
			end
		end
		thdTRIG = 0;
	end

	// SCLK rising
	always @(posedge inSCLK) begin
		speed_check(1);
		case (iPhase)
			phsCMD1: begin
				regCOMD[iThd][iIndex] = inSIO0;
				if (iIndex == iRange) COMD_next_phase;
				else iIndex = iIndex - 1;
			end
			phsCMD4: begin
				regCOMD[iThd][iIndex] = inSIO3; iIndex = iIndex - 1;
				regCOMD[iThd][iIndex] = inSIO2; iIndex = iIndex - 1;
				regCOMD[iThd][iIndex] = inSIO1; iIndex = iIndex - 1;
				regCOMD[iThd][iIndex] = inSIO0;
				if (iIndex == iRange) COMD_next_phase;
				else iIndex = iIndex - 1;
			end
			phsADR1: begin
				regADDR[iThd][iIndex] = inSIO0;
				if (iIndex == iRange) ADDR_next_phase;
				else iIndex = iIndex - 1;
			end
			phsADR2: begin
				if (EHMD == 1) begin
					regEHIN[iEhidx] = inSIO1; iEhidx = iEhidx - 1;
					regEHIN[iEhidx] = inSIO0; iEhidx = iEhidx - 1;
				end
				regADDR[iThd][iIndex] = inSIO1; iIndex = iIndex - 1;
				regADDR[iThd][iIndex] = inSIO0;
				if (iIndex == iRange) ADDR_next_phase;
				else iIndex = iIndex - 1;
			end
			phsADR4: begin
				if (EHMD == 1) begin
					regEHIN[iEhidx] = inSIO3; iEhidx = iEhidx - 1;
					regEHIN[iEhidx] = inSIO2; iEhidx = iEhidx - 1;
					regEHIN[iEhidx] = inSIO1; iEhidx = iEhidx - 1;
					regEHIN[iEhidx] = inSIO0; iEhidx = iEhidx - 1;
				end
				regADDR[iThd][iIndex] = inSIO3; iIndex = iIndex - 1;
				regADDR[iThd][iIndex] = inSIO2; iIndex = iIndex - 1;
				regADDR[iThd][iIndex] = inSIO1; iIndex = iIndex - 1;
				regADDR[iThd][iIndex] = inSIO0;
				if (iIndex == iRange) ADDR_next_phase;
				else iIndex = iIndex - 1;
			end
			phsDMY1: begin
				regDUMY[iThd][iIndex] = inSIO0;
				if (iIndex == iRange) DUMY_next_phase;
				else iIndex = iIndex - 1;
			end
			phsDMY2: begin
				if (iBit > 0) begin
					iBit = iBit - 1; regDUMY[iThd][iBit] = inSIO1;
					iBit = iBit - 1; regDUMY[iThd][iBit] = inSIO0;
				end
				if (iIndex == iRange) DUMY_next_phase;
				else iIndex = iIndex - 1;
			end
			phsDMY4: begin
				if (iBit > 0) begin
					iBit = iBit - 1; regDUMY[iThd][iBit] = inSIO3;
					iBit = iBit - 1; regDUMY[iThd][iBit] = inSIO2;
					iBit = iBit - 1; regDUMY[iThd][iBit] = inSIO1;
					iBit = iBit - 1; regDUMY[iThd][iBit] = inSIO0;
				end
				if (iIndex == iRange) DUMY_next_phase;
				else iIndex = iIndex - 1;
			end
			phsDIN1: bits_din(1);
			phsDIN2: bits_din(2);
			phsDIN4: bits_din(4);
		endcase
	end

	// SCLK falling
	always @(negedge inSCLK) begin
		speed_check(0);
		if (iPhase != phsIDLE) iClock = iClock + 1;
		case (iPhase)
			phsOUT1: bits_out(1);
			phsOUT2: bits_out(2);
			phsOUT4: bits_out(4);
		endcase
	end

	// RESET_b falling
	always @(negedge inRESET_b) begin
		if (ENRESET) during_reset;
	end

	task COMD_next_phase;
	begin
		set_strCOMD;
		if (regCOMD[iThd] != cmdRST) bit_write(oriMODE, bitRSTEN, 0);
		if (dp_disabled(regCOMD[iThd]) == 1) iPhase = phsFAIL;
		if (sotp_disabled(regCOMD[iThd]) == 1) iPhase = phsFAIL;
		if (qe_disabled(regCOMD[iThd]) == 1) iPhase = phsFAIL;
		if (qpi_disabled(regCOMD[iThd]) == 1) iPhase = phsFAIL;
		if (iPhase == phsFAIL) disable COMD_next_phase;
		iSkips = 0;

		case (regCOMD[iThd])
			cmdQPIID: begin
				iIndex = oriRDID;
				iRange = endRDID; regAOUT = iIndex;
				iPhase = phsOUT4;
			end
			cmdRDID: begin
				iIndex = oriRDID;
				iRange = endRDID; regAOUT = iIndex;
				iPhase = phsOUT1;
			end
			cmdRDSR: begin
				iIndex = oriSREG;
				iRange = endSREG; regAOUT = iIndex;
				iPhase = QPI == 1 ? phsOUT4 : phsOUT1;
			end
			cmdRDSCUR: begin
				iIndex = oriSCUR;
				iRange = endSCUR; regAOUT = iIndex;
				iPhase = QPI == 1 ? phsOUT4 : phsOUT1;
			end
			cmdRDCR: begin
				iIndex = oriCREG;
				iRange = endCREG; regAOUT = iIndex;
				iPhase = QPI == 1 ? phsOUT4 : phsOUT1;
			end
			cmdRDFMSR: begin
				iIndex = oriFMSR;
				iRange = endFMSR; regAOUT = iIndex;
				iPhase = QPI == 1 ? phsOUT4 : phsOUT1;
			end
			cmdRES: begin
				iIndex = msbADDR;
				iRange = lsbADDR;
				iPhase = QPI == 1 ? phsADR4 : phsADR1;
			end
			cmdRDLR: begin
				iIndex = oriLREG;
				iRange = endLREG; regAOUT = iIndex;
				iPhase = WPSEL == 1 ? phsOUT1 : phsFAIL;
			end
			cmdRDSPB,
			cmdRDDPB: begin
				iIndex = msbAD4B;
				iRange = lsbAD4B;
				iPhase = phsADR1;
			end
			cmdREMS: begin
				iIndex = msbADDR;
				iRange = lsbADDR;
				iPhase = phsADR1;
			end
			cmdRDSFDP: begin
				iIndex = msbAD3B;
				iRange = lsbAD3B;
				iPhase = phsADR1;
			end
			cmdFASTREAD: begin
				iIndex = msbADDR;
				iRange = lsbADDR;
				iPhase = phsADR1;
			end
			cmdREAD,
			cmdDREAD,
			cmdQREAD: begin
				iIndex = msbADDR;
				iRange = lsbADDR;
				iPhase = phsADR1;
			end
			cmd2READ: begin
				iIndex = msbADDR;
				iRange = lsbADDR;
				iPhase = phsADR2;
			end
			cmd4READ: begin
				iIndex = msbADDR;
				iRange = lsbADDR;
				iPhase = phsADR4;
			end
			cmdW4READ: begin
				iIndex = msbADDR;
				iRange = lsbADDR;
				iPhase = phsADR4;
			end
			cmdDP: begin
				iRange = lsbCOMD;
				iEvent = phsEXE1;
			end
			cmdFMEN,
			cmdEQIO,
			cmdRSTQIO: begin
				iIndex = msbCOMD;
				iRange = lsbCOMD;
				iEvent = phsEXE8;
			end
			cmdWPSEL,
			cmdWREN,
			cmdWRDI,
			cmdWRSCUR,
			cmdENSO,
			cmdEXSO: begin
				iIndex = msbCOMD;
				iRange = lsbCOMD;
				iEvent = phsEXE1;
			end
			cmdSBL: begin
				iIndex = oriDATA; iBit = `bitsBYTE; thdLen[iThd] = 0;
				iRange = endDATA;
				iEvent = phsEXE8;
				iPhase = QPI == 1 ? phsDIN4 : phsDIN1;
			end
			cmdCE_1,
			cmdCE_2,
			cmdRSM_1,
			cmdRSM_2: begin
				iIndex = msbCOMD;
				iRange = lsbCOMD;
				iEvent = phsEXEC;
			end
			cmdRSTEN,
			cmdRST,
			cmdNOP,
			cmdSUS_1,
			cmdSUS_2: begin
				iIndex = msbCOMD;
				iRange = lsbCOMD;
				iEvent = phsINTR;
			end
			cmdWRSR: begin
				iIndex = oriDATA; iBit = `bitsBYTE; thdLen[iThd] = 0;
				iRange = endDATA;
				iEvent = phsEXEC;
				iPhase = QPI == 1 ? phsDIN4 : phsDIN1;
			end
			cmdSE,
			cmdBE,
			cmdBE32K,
			cmdPP: begin
				iIndex = msbADDR;
				iRange = lsbADDR;
				iEvent = phsEXEC;
				iPhase = QPI == 1 ? phsADR4 : phsADR1;
			end
			cmd4PP: begin
				iIndex = msbADDR;
				iRange = lsbADDR;
				iPhase = phsADR4;
				iEvent = phsEXEC;
			end
			cmdWRLR: begin
				iIndex = oriDATA; iBit = `bitsBYTE; thdLen[iThd] = 0;
				iRange = endDATA;
				iPhase = phsDIN1;
				iEvent = WPSEL == 1 ? phsEXEC : phsFAIL;
			end
			cmdGBLK,
			cmdGBULK: begin
				iIndex = msbCOMD;
				iRange = lsbCOMD;
				iEvent = WPSEL == 1 ? phsEXEC : phsFAIL;
			end
			cmdESSPB,
			cmdWRSPB,
			cmdWRDPB: begin
				iIndex = msbAD4B;
				iRange = lsbAD4B;
				iPhase = phsADR1;
				iEvent = WPSEL == 1 ? phsEXEC : phsFAIL;
			end
			default: begin
				$display ("*ERROR* Unknown COMMAND code: %h", regCOMD[iThd]);
				iPhase = phsFAIL;
			end
		endcase
		if (iPhase != phsFAIL) dummy_speed;
	end
	endtask

	task ADDR_next_phase;
	begin
		iSkips = 0;
		case (regCOMD[iThd])
			cmdRES: begin
				iIndex = endREMS;
				iRange = endREMS; regAOUT = endREMS; iBit = `bitsBYTE;
				iPhase = QPI == 1 ? phsOUT4 : phsOUT1;
			end
			cmdREMS: begin
				iIndex = (regADDR[iThd] & 1) == 0 ? oriREMS : endREMS;
				iRange = endREMS; regAOUT = oriREMS;
				iPhase = phsOUT1;
			end
			cmdREAD: begin
				if (SOTP == 1) begin
					iIndex = (regADDR[iThd] & endSOTP) | oriSOTP;
					iRange = endSOTP; regAOUT = oriSOTP;
				end
				else begin
					iIndex = (regADDR[iThd] & endMAIN) | oriMAIN;
					iRange = endMAIN; regAOUT = oriMAIN;
				end
				iPhase = phsOUT1;
			end
			cmdRDSFDP: begin
				iIndex = dummy_cycle(regCOMD[iThd]);
				iRange = lsbBYTE;
				iPhase = phsDMY1;
			end
			cmdFASTREAD: begin
				iIndex = dummy_cycle(regCOMD[iThd]);
				iRange = lsbBYTE;
				iPhase = phsDMY1;
			end
			cmdDREAD,
			cmd2READ: begin
				iIndex = dummy_cycle(regCOMD[iThd]);
				iRange = lsbBYTE; iBit = `bitsBYTE;
				iPhase = phsDMY2;
			end
			cmdQREAD,
			cmd4READ: begin
				iIndex = dummy_cycle(regCOMD[iThd]);
				iRange = lsbBYTE; iBit = `bitsBYTE;
				iPhase = phsDMY4;
			end
			cmdW4READ: begin
				iIndex = dummy_cycle(regCOMD[iThd]);
				iRange = lsbBYTE; iBit = `bitsBYTE;
				iPhase = phsDMY4;
			end
			cmdPP: begin
				iIndex = oriDATA; thdLen[iThd] = 0;
				iRange = endDATA; iBit = `bitsBYTE;
				iPhase = QPI == 1 ? phsDIN4 : phsDIN1;
			end
			cmd4PP: begin
				iIndex = oriDATA; thdLen[iThd] = 0;
				iRange = endDATA; iBit = `bitsBYTE;
				iPhase = phsDIN4;
			end
			cmdSE,
			cmdBE32K,
			cmdBE: begin
				iIndex = oriDATA;
				iRange = endDATA;
				iPhase = phsEXEC;
			end
			cmdRDDPB: begin
				iIndex = oriDPBR + WPSEL_offset(regADDR[iThd]);
				iRange = iIndex;
				regAOUT = iIndex; iBit = `bitsBYTE;
				iPhase = WPSEL == 1 ? phsOUT1 : phsFAIL;
			end
			cmdWRDPB: begin
				iIndex = oriDATA;
				iRange = oriDATA; thdLen[iThd] = 0;
				iPhase = phsDIN1; iBit = `bitsBYTE;
			end
			cmdRDSPB: begin
				iIndex = oriSPBR + WPSEL_offset(regADDR[iThd]);
				iRange = iIndex;
				regAOUT = iIndex; iBit = `bitsBYTE;
				iPhase = WPSEL == 1 ? phsOUT1 : phsFAIL;
			end
			cmdESSPB,
			cmdWRSPB: begin
				iPhase = phsEXEC;
			end
			default: begin
				$display ("*ERROR* Unknown ADDR_next_phase: %h", regCOMD[iThd]);
				iPhase = phsFAIL;
			end
		endcase
	end
	endtask

	task DUMY_next_phase;
		reg [msbADDR:lsbADDR] oriAddr, endAddr;
	begin
		if (SOTP == 1) begin
			oriAddr = oriSOTP; endAddr = endSOTP;
		end
		else begin
			oriAddr = oriMAIN; endAddr = endMAIN;
		end

		case (regCOMD[iThd])
			cmdRDSFDP: begin
				iIndex = (regADDR[iThd] & endSFDP) | oriSFDP;
				iRange = endSFDP; regAOUT = oriSFDP; iBit = `bitsBYTE;
				iPhase = phsOUT1;
			end
			cmdFASTREAD: begin
				iIndex = (regADDR[iThd] & endAddr) | oriAddr;
				iRange = endAddr; regAOUT = oriAddr;
				iPhase = phsOUT1;
			end
			cmdDREAD: begin
				iIndex = (regADDR[iThd] & endAddr) | oriAddr;
				iRange = endAddr;
				iPhase = phsOUT2; regAOUT = oriAddr; iBit = `bitsBYTE;
			end
			cmd2READ: begin
				iIndex = (regADDR[iThd] & endAddr) | oriAddr;
				iRange = endAddr;
				iPhase = phsOUT2; regAOUT = oriAddr; iBit = `bitsBYTE;
			end
			cmdQREAD: begin
				iIndex = (regADDR[iThd] & endAddr) | oriAddr;
				iRange = endAddr;
				iPhase = phsOUT4; regAOUT = oriAddr; iBit = `bitsBYTE;
			end
			cmd4READ: begin
				iIndex = (regADDR[iThd] & endAddr) | oriAddr;
				iRange = endAddr; regAOUT = oriAddr; iBit = `bitsBYTE;
				iPhase = phsOUT4;
				wrap_condition;
				bit_write(oriMODE, bitEHMD, enhance_mode(4));
			end
			cmdW4READ: begin
				iIndex = (regADDR[iThd] & endAddr) | oriAddr;
				iRange = endAddr; regAOUT = oriAddr; iBit = `bitsBYTE;
				iPhase = phsOUT4;
				wrap_condition;
			end
			default: begin
				$display ("*ERROR* Unknown DUMY_next_phase: %h", regCOMD[iThd]);
				iPhase = phsFAIL;
			end
		endcase
	end
	endtask

	task bit_write;
		input [msbARRY:lsbARRY] addr;
		input [msbBYTE:lsbBYTE] ibit;
		input value;
	begin
		mxArray[addr][ibit] = value;
	end
	endtask

	task bit_delay;
		input [msbARRY:lsbARRY] addr;
		input [msbBYTE:lsbBYTE] ibit;
		input value;
		input delay;
		realtime delay;
	begin
		mxArray[addr][ibit] <= #delay value;
	end
	endtask

	task byte_write;
		input [msbARRY:lsbARRY] addr;
		input [msbBYTE:lsbBYTE] mask;
		input [msbBYTE:lsbBYTE] data;
	begin
		mxArray[addr] = (mxArray[addr] & ~mask) | (data & mask);
	end
	endtask

	task write_exec_bit;
	begin
		if (thdLen[iThd] != 0
		||  wip_disabled(regCOMD[iThd])
		||  sus_disabled(regCOMD[iThd])
		||  wel_disabled(regCOMD[iThd])) begin
			iPhase = phsFAIL;
			disable write_exec_bit;
		end

		case (regCOMD[iThd])
			cmdWREN:   bit_write(oriSREG, bitWEL, 1);
			cmdWRDI:   bit_write(oriSREG, bitWEL, 0);
			cmdENSO:   bit_write(oriMODE, bitSOTP, 1);
			cmdEXSO:   bit_write(oriMODE, bitSOTP, 0);
			cmdWRSCUR: bit_write(oriSCUR, bitLDSO, 1);
			cmdWPSEL:  bit_write(oriSCUR, bitWPSEL, 1);
			cmdDP: begin
				bit_write(oriMODE, bitDP, 1);
				bit_write(oriMODE, bitDPDD, 1);
				bit_delay(oriMODE, bitDPDD, 0, tDPDD);
				tcDP <= 1;
				tcDP <= #(tDP + tDPDD) 0;
			end
		endcase
	end
	endtask

	task write_exec_byte;
	begin
		if (len_disabled(regCOMD[iThd], thdLen[iThd]) == 1) begin
			iPhase = phsFAIL;
			disable write_exec_byte;
		end

		case (regCOMD[iThd])
			cmdFMEN:   byte_write(oriFMSR, `bitsBYTE'hFF, `bitsBYTE'hFF);
			cmdSBL:    byte_write(oriSBLR, mskSBLR, regDATA[iThd][oriDATA]);
			cmdEQIO:   byte_write(oriINTF, itfMSK, itfQPI);
			cmdRSTQIO: byte_write(oriINTF, itfMSK, mxArray[oriITFDEF]);
		endcase
	end
	endtask

	task write_exec_wip;
		integer i, thdexe, len, adr_mx, adr_pg, adr_dt, adr_bd;
		reg prot;
		time twip;
	begin
		if (wel_disabled(regCOMD[iThd])
		||  len_disabled(regCOMD[iThd], thdLen[iThd]) == 1) begin
			iPhase = phsFAIL;
			disable write_exec_wip;
		end
		bit_write(oriSREG, bitWIP, 1);
		thdWIP[iThd] = 1;

		write_protected(iThd, prot);
		if (prot == 1) disable write_exec_wip;

		thdexe = iThd;
		len = thdLen[thdexe];
		case (regCOMD[iThd])
			cmdESSPB,
			cmdWRSPB,
			cmdWRLR: begin
				twip = tBP;
			end
			cmdWRDPB,
			cmdGBLK,
			cmdGBULK: begin
				twip = 0;
			end
			cmdWRSR: begin
				twip = tW;
			end
			cmdSE: begin
				adr_mx = ((regADDR[thdexe] & endMAIN) | oriMAIN) & ~endSECT;
				adr_bd = adr_mx + `sizeSECT;
				while (adr_mx < adr_bd) begin
					byte_write(adr_mx, `bitsBYTE'hFF, `bitsBYTE'hxx);
					adr_mx = adr_mx + 1;
				end
				twip = tSE;
				if (FMD) twip = tSE_FMD;
			end
			cmdBE32K: begin
				adr_mx = ((regADDR[thdexe] & endMAIN) | oriMAIN) & ~endB32K;
				adr_bd = adr_mx + `sizeB32K;
				while (adr_mx < adr_bd) begin
					byte_write(adr_mx, `bitsBYTE'hFF, `bitsBYTE'hxx);
					adr_mx = adr_mx + 1;
				end
				twip = tBE32;
				if (FMD) twip = tBE32_FMD;
			end
			cmdBE: begin
				adr_mx = ((regADDR[thdexe] & endMAIN) | oriMAIN) & ~endBLOK;
				adr_bd = adr_mx + `sizeBLOK;
				while (adr_mx < adr_bd) begin
					byte_write(adr_mx, `bitsBYTE'hFF, `bitsBYTE'hxx);
					adr_mx = adr_mx + 1;
				end
				twip = tBE;
				if (FMD) twip = tBE_FMD;
			end
			cmdCE_1,
			cmdCE_2: begin
				for (i = oriMAIN; i <= endMAIN; i = i + 1) begin
					byte_write(i, `bitsBYTE'hFF, `bitsBYTE'hxx);
				end
				twip = tCE_ms * `unit_ms;
				if (FMD) twip = tCE_FMD_ms * `unit_ms;
			end
			cmdPP,
			cmd4PP: begin
				if (SOTP == 1) adr_mx = (regADDR[thdexe] & endSOTP) | oriSOTP;
				else           adr_mx = (regADDR[thdexe] & endMAIN) | oriMAIN;
				adr_pg = adr_mx & ~endDATA;
				if (len > `sizeDATA) len = `sizeDATA; // DATA wrap
				adr_dt = oriDATA;
				for (i = 0; i < len; i = i + 1) begin
					regDATA[thdexe][adr_dt] = regDATA[thdexe][adr_dt] & mxArray[adr_mx];
					mxArray[adr_mx] = `bitsBYTE'hxx;
					adr_dt = (adr_dt + 1) & endDATA;
					adr_mx = adr_pg | ((adr_mx + 1) & endDATA);
				end
				twip = tPP_calculator(thdLen[iThd]);
			end
			cmdRSM_1,
			cmdRSM_2: begin
				thdexe = 0;
				for (i = 1; i <= `sizeTHRD; i = i + 1) begin
					if (thdTSUS[i] > 0) thdexe = i;
				end
				if (thdexe == 0) begin
					bit_write(oriSREG, bitWIP, 0);
					thdWIP[iThd] = 0;
					disable write_exec_wip;
				end
				thread_sus_rsm(1, thdexe);
				twip = thdTOUT[thdexe] - thdTSUS[thdexe];
				thdTSUS[thdexe] = 0;
				bit_write(oriSREG, bitWEL, 1);
				thdWIP[iThd] = 0;
			end
		endcase
		thdTOUT[thdexe] = $time + twip;
		thdTRIG <= #twip 1;

		if (thdWIP[iThd] == 1) ithd_next(iThd);
	end
	endtask

	task thd_wip_exec;
		input integer thrd;
		integer i, len, adr_mx, adr_pg, adr_dt, adr_bd;
	begin
		if (iPhase == phsINIT) begin //reset recovery event
			if (inRESET_b == 0) @ (posedge inRESET_b);
			system_reset;
			iPhase = phsIDLE;
			disable thd_wip_exec;
		end

		len = thdLen[thrd];

		case (regCOMD[thrd])
			cmdWRSR: begin
				byte_write (oriSREG, mxArray[oriSRMSK], regDATA[thrd][oriDATA]);
				if (len > 1) begin
					otp_reg_write (thrd, 1, oriCREG, oriDATA + 1, oriCRMSK, oriCROTP);
				end
			end
			cmdWRLR: begin
				otp_reg_write (thrd, `sizeLREG, oriLREG, oriDATA, oriLRMSK, oriLROTP);
			end
			cmd4PP,
			cmdPP: begin
				if (SOTP == 1) adr_mx = (regADDR[thrd] & endSOTP) | oriSOTP;
				else           adr_mx = (regADDR[thrd] & endMAIN) | oriMAIN;
				adr_pg = adr_mx & ~endDATA;
				if (len > `sizeDATA) len = `sizeDATA; // DATA wrap
				adr_dt = oriDATA;

				for (i = 0; i < len; i = i + 1) begin
					mxArray[adr_mx] = regDATA[thrd][adr_dt];
					adr_dt = (adr_dt + 1) & endDATA;
					adr_mx = adr_pg | ((adr_mx + 1) & endDATA);
				end
			end
			cmdSE: begin
				adr_mx = ((regADDR[thrd] & endMAIN) | oriMAIN) & ~endSECT;
				adr_bd = adr_mx + `sizeSECT;
				while (adr_mx < adr_bd) begin
					mxArray[adr_mx] = `bitsBYTE'hFF;
					adr_mx = adr_mx + 1;
				end
			end
			cmdBE32K: begin
				adr_mx = ((regADDR[thrd] & endMAIN) | oriMAIN) & ~endB32K;
				adr_bd = adr_mx + `sizeB32K;
				while (adr_mx < adr_bd) begin
					mxArray[adr_mx] = `bitsBYTE'hFF;
					adr_mx = adr_mx + 1;
				end
			end
			cmdBE: begin
				adr_mx = ((regADDR[thrd] & endMAIN) | oriMAIN) & ~endBLOK;
				adr_bd = adr_mx + `sizeBLOK;
				while (adr_mx < adr_bd) begin
					mxArray[adr_mx] = `bitsBYTE'hFF;
					adr_mx = adr_mx + 1;
				end
			end
			cmdCE_1,
			cmdCE_2: begin
				for (i = oriMAIN; i <= endMAIN; i = i + 1) begin
					mxArray[i] = `bitsBYTE'hFF;
				end
			end
			cmdWRDPB: begin
				adr_mx = oriDPBR + WPSEL_offset(regADDR[thrd]);
				if (regDATA[thrd][oriDATA]) begin
					byte_write(adr_mx, mskDPBR, `bitsBYTE'hFF);
				end
				else byte_write(adr_mx, mskDPBR, `bitsBYTE'h00);
			end
			cmdGBLK: begin
				for (i = oriDPBR; i <= endDPBR; i = i + 1) begin
					byte_write(i, mskDPBR, `bitsBYTE'hFF);
				end
			end
			cmdGBULK: begin
				for (i = oriDPBR; i <= endDPBR; i = i + 1) begin
					byte_write(i, mskDPBR, `bitsBYTE'h00);
				end
			end
			cmdESSPB: begin
				for (i = oriSPBR; i <= endSPBR; i = i + 1) begin
					byte_write(i, mskSPBR, `bitsBYTE'h00);
				end
			end
			cmdWRSPB: begin
				adr_mx = oriSPBR + WPSEL_offset(regADDR[thrd]);
				byte_write(adr_mx, mskSPBR, `bitsBYTE'hFF);
			end
		endcase
		bit_write(oriSREG, bitWEL, 0);
		bit_write(oriSREG, bitWIP, 0);
		fmd_released(regCOMD[thrd]);
		thread_clean(thrd);
	end
	endtask

	task otp_reg_write;
		input integer thrd;
		input integer len;
		input [msbARRY:lsbARRY] ireg;
		input [msbDATA:lsbDATA] idat;
		input [msbARRY:lsbARRY] imsk;
		input [msbARRY:lsbARRY] iotp;
		reg   [msbBYTE:lsbBYTE] changebit;
		integer i;
	begin
		for (i = 0; i < len; i = i + 1) begin
			changebit = (mxArray[ireg + i] ^ regDATA[thrd][idat + i]) & mxArray[imsk + i];
			byte_write (ireg + i, mxArray[imsk + i], regDATA[thrd][idat + i]);
			mxArray[imsk + i] = mxArray[imsk + i] & ~(changebit & mxArray[iotp + i]);
		end
	end
	endtask

	task write_exec_intr;
		integer i, thditr;
	begin
		if (thdLen[iThd] != 0 || fmd_disabled(regCOMD[iThd])) begin
			iPhase = phsFAIL;
			disable write_exec_intr;
		end

		case (regCOMD[iThd])
			cmdRST:   if (RSTEN == 1) during_reset;
			cmdRSTEN: bit_write(oriMODE, bitRSTEN, 1);
			cmdSUS_1,
			cmdSUS_2: begin
				thditr = 0;
				for (i = 1; i <= `sizeTHRD + 1; i = i + 1) begin
					if (thdTOUT[i] > $time) thditr = i;
				end
				if ((ESUS | PSUS | PR2S) == 1 || WIP == 0 || thditr == 0) begin
					disable write_exec_intr;
				end
				thread_sus_rsm(0, thditr);
				bit_write(oriMODE, bitPR2S, 1);
				thdTSUS[thditr] = $time;
			end
		endcase
	end
	endtask

	task during_reset;
		integer thrd;
		time trst;
	begin
		iPhase = phsINIT;
		outSIO0 = 1'bz;
		outSIO1 = 1'bz;
		outSIO2 = 1'bz;
		outSIO3 = 1'bz;
		thrd = 0;
		for (i = 1; i <= `sizeTHRD; i = i + 1) begin
			if (thdTOUT[i] > $time) thrd = i;
		end
        if (thrd != 0) begin
            case (regCOMD[thrd])
                cmdSE:   trst = tREADY2_SE;
                cmdBE32K,
                cmdBE:   trst = tREADY2_BE;
                cmdCE_1,
                cmdCE_2: trst = tREADY2_CE;
                cmdPP,
                cmd4PP:  trst = tREADY2_P;
                cmdWRSR: trst = tREADY2_W;
                default: trst = tREADY2_D;
            endcase
        end
        else begin
            thrd = iThd;
            if (iPhase & phmOUT) trst = tREADY2_R;
            else trst = tREADY2_D;
			if (DP == 1) begin
				trst = tRDP;
			end
        end
		thdTOUT[thrd] = $time + trst;
		thdTSUS[thrd] = 0;
		thdTRIG <= #trst 1;
	end
	endtask

	task system_reset;
		integer i;
	begin
		thdTRIG = 0;
		iThd = 1;
		for (i = 1; i <= `sizeTHRD; i = i + 1) begin
			regADDR[i] = 0;
			thread_clean(i);
		end
		tcDP = 0;
		byte_write(oriSREG, mxArray[oriSRVOL], mxArray[oriSRDEF]); // Status Register
		byte_write(oriSCUR, mxArray[oriSCVOL], mxArray[oriSCDEF]); // Security Register
		byte_write(oriCREG, mxArray[oriCRVOL], mxArray[oriCRDEF]); // Config Register
		for(i = 0; i <= `sizeLREG - 1; i = i + 1) begin
			byte_write(oriLREG + i, mxArray[oriLRVOL + i], mxArray[oriLRDEF + i]); // Lock Register
		end
		mxArray[oriSBLR] = `bitsBYTE'hFF; // Burst Length Register
		for (i = oriDPBR; i <= endDPBR; i = i + 1) mxArray[i] = `bitsBYTE'hFF;
		mxArray[oriFMSR] = `bitsBYTE'h00;
		mxArray[oriMODE] = `bitsBYTE'h00;
		mxArray[oriINTF] = mxArray[oriITFDEF];
	end
	endtask

	task write_protected;
		input integer thrd;
		output prot;
		reg [msbDATA:lsbDATA] regdt;
		reg aprot, pgm, ers;
		time tchk;
	begin
		if (SOTP == 1) begin
			aprot = (LDSO == 1 && (regADDR[thrd] < `sizeSOTP >> 1)
			      || FLSO == 1 && (regADDR[thrd] >= `sizeSOTP >> 1)) ? 1 : 0;
		end
		else if (WPSEL == 1) begin
			aprot = WPSEL_protection(regCOMD[thrd], regADDR[thrd]);
			if (inWP_b == 0 && ENWP == 1) aprot = 1;
		end
		else begin
			aprot = block_lock_protection(regADDR[thrd]);
		end

		case (regCOMD[thrd])
			cmdCE_1,
			cmdCE_2: begin
				pgm = 0; ers = 1;
				prot = mxArray[oriSREG][bitBP3:bitBP0] == 0 ? 0 : 1;
				if (WPSEL == 1) prot = aprot == 1 ? 1 : 0;
				tchk = tERS_CHK;
			end
			cmdSE,
			cmdBE32K,
			cmdBE: begin
				pgm = 0; ers = 1;
				tchk = tERS_CHK;
				prot = aprot == 1 ? 1 : 0;
			end
			cmdPP,
			cmd4PP: begin
				pgm = 1; ers = 0;
				tchk = tPGM_CHK;
				prot = aprot == 1 ? 1 : 0;
			end
			cmdWRSR: begin
				pgm = 1; ers = 0;
				tchk = 0;
				if (SRWD == 1 && inWP_b == 0 && ENWP == 1) prot = 1;
				else prot = 0;
			end
			cmdWRLR: begin
				pgm = 1; ers = 0;
				tchk = 0;
				prot = (SPBLK == mxArray[oriLRDEF][bitSPBLKDN]) ? 1 : 0;
			end
			cmdESSPB,
			cmdWRSPB: begin
				pgm = 1; ers = 0;
				tchk = 0;
				prot = SPBLK == 1 ? 1 : 0;
			end
			default: begin
				pgm = 0; ers = 0; tchk = 0; prot = 0;
			end
		endcase

		if (prot == 1) begin
			thdWIP[thrd] <= #tchk 0;
			bit_delay(oriSREG, bitWIP, 0, tchk);
			bit_delay(oriSREG, bitWEL, 0, tchk);
		end
		if (pgm == 1) bit_delay (oriSCUR, bitPFAIL, prot, tchk);
		if (ers == 1) bit_delay (oriSCUR, bitEFAIL, prot, tchk);
	end
	endtask

	task tshsl_cancel;
		input integer ithd;
		integer cthd;
	begin
		cthd = thdPRE[ithd];
		if (cthd == 0) disable tshsl_cancel;

		if (thdTOUT[cthd] > $time && thdTSUS[cthd] == 0) begin
			thread_clean(cthd);
			$display ("*ERROR* Command %h is disalbed by tSHSL_W violation.", regCOMD[cthd]);
		end
	end
	endtask

	task thread_clean;
		input integer thrd;
	begin
		thdTOUT[thrd] = 'dx;
		thdTSUS[thrd] = 0;
		thdWIP[thrd]  = 0;
		thdPRE[thrd]  = 0;
	end
	endtask

	task thread_sus_rsm;
		input mode; // 0 = susepnd, 1 = resume
		input integer thrd;
	begin
		case (regCOMD[thrd])
			cmdSE,
			cmdBE32K,
			cmdBE: begin
				// for suspend case
				if (mode == 0) begin
					bit_delay(oriSCUR, bitESB, 1, tESL);
					bit_delay(oriSREG, bitWIP, 0, tESL);
					bit_delay(oriSREG, bitWEL, 0, tESL);
				end
				// for resume case
				else begin
					bit_write(oriSCUR, bitESB, 0);
					bit_delay(oriMODE, bitPR2S, 0, tERS);
				end
			end
			cmdPP,
			cmd4PP: begin
				// for suspend case
				if (mode == 0) begin
					bit_delay(oriSCUR, bitPSB, 1, tPSL);
					bit_delay(oriSREG, bitWIP, 0, tPSL);
					bit_delay(oriSREG, bitWEL, 0, tPSL);
				end
				// for resume case
				else begin
					bit_write(oriSCUR, bitPSB, 0);
					bit_delay(oriMODE, bitPR2S, 0, tPRS);
				end
			end
		endcase
	end
	endtask

	task bits_din;
		input [msbBYTE:lsbBYTE] bits;
	begin
		if (WIP) begin
			iPhase = phsFAIL;
			disable bits_din;
		end

		if (bits == 4) begin
			iBit = iBit - 1; regDATA[iThd][iIndex][iBit] = inSIO3;
			iBit = iBit - 1; regDATA[iThd][iIndex][iBit] = inSIO2;
		end
		if (bits >= 2) begin
			iBit = iBit - 1; regDATA[iThd][iIndex][iBit] = inSIO1;
		end
		if (bits >= 1) begin
			iBit = iBit - 1; regDATA[iThd][iIndex][iBit] = inSIO0;
		end

		if (iBit == 0) begin
			iBit = `bitsBYTE;
			thdLen[iThd] = thdLen[iThd] + 1;
			if (iIndex == iRange) iIndex = oriDATA;
			else iIndex = iIndex + 1;
		end
	end
	endtask

	task bits_out;
		input [msbBYTE:lsbBYTE] bits;
		realtime tclqv;
	begin
		if (wip_disabled(regCOMD[iThd])) begin
			iPhase = phsFAIL;
			disable bits_out;
		end

		tclqv = tCLQV;
		if (bits == 4) begin
			iBit = iBit - 1; outSIO3 <= #tclqv mxArray[iIndex][iBit];
			iBit = iBit - 1; outSIO2 <= #tclqv mxArray[iIndex][iBit];
		end
		if (bits >= 1) begin
			iBit = iBit - 1; outSIO1 <= #tclqv mxArray[iIndex][iBit];
		end
		if (bits >= 2) begin
			iBit = iBit - 1; outSIO0 <= #tclqv mxArray[iIndex][iBit];
		end

		if (iBit == 0) begin
			iBit = `bitsBYTE;
			if (iIndex == iRange) iIndex = regAOUT;
			else iIndex = iIndex + 1;
		end
	end
	endtask

	task wrap_condition;
		reg [msbBYTE:lsbBYTE] mask;
	begin
		if ((mxArray[oriSBLR] & mskWRAP) == 0
		&&  (iIndex >= oriMAIN) && (iIndex <= endMAIN))
		begin
			mask = (lenSBLR << (mxArray[oriSBLR] & mskSBLR)) - 1;
			iRange = iIndex | mask;
			regAOUT = iIndex & ~mask;
		end
	end
	endtask

	function enhance_mode;
		input [msbBYTE:lsbBYTE] bits;
		reg   [msbBYTE:lsbBYTE] idx;
	begin
		enhance_mode = 1;
		idx = `bitsBYTE - 1;
		while (idx >= (`bitsBYTE - bits)) begin
			enhance_mode = enhance_mode
			             & (regDUMY[iThd][idx] ^ regDUMY[iThd][idx - bits]);
			if (regDUMY[iThd][idx] === 1'bz
			||  regDUMY[iThd][idx - bits] === 1'bz) begin
				enhance_mode = 1'bz;
				idx = 0;
			end
			else idx = idx - 1;
		end
		if (enhance_mode === 1'bz) begin
			$write("*ERROR* Hi-impedance is inhibited for the two clock cycle");
			$write(" during dummy cycle\n");
			enhance_mode = 0;
			iPhase = phsFAIL;
		end
		if (enhance_mode == 1) regEHMD = regCOMD[iThd];
	end
	endfunction

	task dp_released;
	begin
		bit_delay(oriMODE, bitDP, 0, tRDP);
		iPhase = phsIDLE;
	end
	endtask

	function dp_disabled;
		input[msbCOMD:lsbCOMD] command;
	begin
		if (DP == 1) begin
			case (command)
				default: dp_disabled = 1;
			endcase
		end
		else dp_disabled = 0;
		if (dp_disabled == 1) begin
			$display ("*ERROR* Command: %h is disabled in DP mode.", command);
		end
	end
	endfunction

	function len_disabled;
		input [msbCOMD:lsbCOMD] command;
		input integer len;
	begin
		case (command)
			cmdWRSR: begin
				len_disabled = (len == 0) || (len > (`sizeSREG + `sizeCREG)) ? 1 : 0;
			end
			cmdPP,
			cmd4PP:  len_disabled = len == 0 ? 1 : 0;
			cmdSBL,
			cmdWRDPB:  len_disabled = len != 1 ? 1 : 0;
			cmdWRLR:   len_disabled = len != `sizeLREG ? 1 : 0;
			default:   len_disabled = 0;
		endcase
		if (len_disabled == 1) begin
			$display ("*ERROR* Input data cycles violation: %h.", command);
		end
	end
	endfunction

	function wip_disabled;
		input [msbCOMD:lsbCOMD] command;
	begin
		if (WIP == 1) begin
			case (command)
				cmdRDSR,
				cmdRDSCUR,
				cmdRDCR: wip_disabled = 0;
				cmdWRDI: wip_disabled = 0;
				default: wip_disabled = 1;
			endcase
		end
		else wip_disabled = 0;
		if (wip_disabled == 1) begin
			$display ("*ERROR* Command %h is disalbed while WIP = 1.", command);
		end
	end
	endfunction

	function wel_disabled;
		input [msbCOMD:lsbCOMD] command;
	begin
		if (WEL == 0) begin
			case (command)
				cmdDP,
				cmdRSM_1,
				cmdRSM_2,
				cmdWREN,
				cmdWRDI,
				cmdFMEN,
				cmdEQIO,
				cmdRSTQIO,
				cmdENSO,
				cmdEXSO: wel_disabled = 0;
				default: wel_disabled = 1;
			endcase
		end
		else wel_disabled = 0;
		if (wel_disabled == 1) begin
			$display ("*ERROR* Command %h is disalbed while WEL = 0.", command);
		end
	end
	endfunction

	function qe_disabled;
		input [msbCOMD:lsbCOMD] command;
	begin
		if (QE == 0) begin
			case (command)
				cmdW4READ,
				cmd4PP,
				cmdQREAD,
				cmd4READ: begin
					if (QPI == 1) qe_disabled = 0;
					else qe_disabled = 1;
				end
				default:  qe_disabled = 0;
			endcase
		end
		else qe_disabled = 0;
		if (qe_disabled == 1) begin
			$display ("*ERROR* Command %h is disalbed while QE = 0.", command);
		end
	end
	endfunction

	function sus_disabled;
		input [msbCOMD:lsbCOMD] command;
	begin
		if (PSUS == 1 || ESUS == 1) begin
			case (command)
				cmdENSO,
				cmdEXSO,
				cmdRDSR,
				cmdRDCR,
				cmdRDSCUR,
				cmdWRDI: sus_disabled = 0;
				default: sus_disabled = 1;
			endcase
		end
		else sus_disabled = 0;
		if (sus_disabled == 1) begin
			$display ("*ERROR* Command %h is disalbed while flash is suspended.", command);
		end
	end
	endfunction

	function qpi_disabled;
		input [msbCOMD:lsbCOMD] command;
	begin
		if (QPI == 1) begin
			case (command)
				cmd4READ,
				cmdPP,
				cmdSE,
				cmdBE32K,
				cmdBE,
				cmdCE_1,
				cmdCE_2,
				cmdWREN,
				cmdWRDI,
				cmdFMEN,
				cmdRDFMSR,
				cmdRDSR,
				cmdRDCR,
				cmdWRSR,
				cmdWPSEL,
				cmdSUS_1,
				cmdSUS_2,
				cmdRSM_1,
				cmdRSM_2,
				cmdDP,
				cmdRES,
				cmdSBL,
				cmdENSO,
				cmdEXSO,
				cmdRDSCUR,
				cmdWRSCUR,
				cmdGBLK,
				cmdGBULK,
				cmdNOP,
				cmdRSTEN,
				cmdRST,
				cmdRSTQIO,
				cmdQPIID: qpi_disabled = 0;
				default: qpi_disabled = 1;
			endcase
			if (qpi_disabled == 1) begin
				$display ("*ERROR* Command %h is disalbed in QPI mode.", command);
			end
		end
		else begin // INTF != itfQPI
			case(command)
				cmdRSTQIO,
				cmdQPIID: qpi_disabled = 1;
				default: qpi_disabled = 0;
			endcase
			if (qpi_disabled == 1) begin
				$display ("*ERROR* Command %h is supported in QPI mode only.", command);
			end
		end
	end
	endfunction

	function sotp_disabled;
		input [msbCOMD:lsbCOMD] command;
	begin
		if (SOTP == 1) begin
			case (command)
				cmdEXSO,
				cmdRDSR,
				cmdRDCR,
				cmdRDSCUR,
				cmdRDID,
				cmdRDLR,
				cmdRDFMSR,
				cmdRDDPB,
				cmdRDSPB,
				cmdREAD,
				cmdFASTREAD,
				cmdDREAD,
				cmd2READ,
				cmdQREAD,
				cmd4READ,
				cmdW4READ,
				cmdPP,
				cmd4PP,
				cmdWREN,
				cmdWRDI: sotp_disabled = 0;
				default: sotp_disabled = 1;
			endcase
		end
		else sotp_disabled = 0;
		if (sotp_disabled == 1) begin
			$display ("*ERROR* Command %h is disalbed in secured OTP area.", command);
		end
	end
	endfunction

	function fmd_disabled;
		input [msbCOMD:lsbCOMD] command;
	begin
		if (FMD == 1) begin
			case (command)
				cmdSUS_1,
				cmdSUS_2: fmd_disabled = 1;
				default:  fmd_disabled = 0;
			endcase
		end
		else fmd_disabled = 0;
		if (fmd_disabled == 1) begin
			$display ("*ERROR* Command %h is disalbed in factory mode.", command);
		end
	end
	endfunction

	task fmd_released;
		input [msbCOMD:lsbCOMD] command;
	begin
		case (command)
			cmdPP,
			cmd4PP,
			cmdSE,
			cmdBE32K,
			cmdBE,
			cmdCE_1,
			cmdCE_2: begin
				byte_write(oriFMSR, `bitsBYTE'hFF, `bitsBYTE'h00);
			end
		endcase
	end
	endtask

	function block_lock_protection;
		input [msbMAIN:lsbMAIN] addr;
		integer bm, ba, bp;
		reg prot;
	begin
		prot = 0;
		bm = (endMAIN - oriMAIN) >> `bitsBLOK;
		ba = (addr >> `bitsBLOK) & bm;
		bp = 1 << (mxArray[oriSREG][bitBP3:bitBP0] - 1);
		if (mxArray[oriSREG][bitBP3:bitBP0] == 0) prot = 0;
		else if (bp > bm) prot = 1;
		else begin
			if (TB == 0 && ba > (bm - bp) || TB == 1 && ba < bp) prot = 1;
			else prot = 0;
		end
		block_lock_protection = prot;
	end
	endfunction

	function integer WPSEL_offset;
		input [msbMAIN:lsbMAIN] addr;
		reg   [msbARRY:lsbARRY] limit;
		integer i;
	begin
		i = 0; limit = `bitsARRY'h0;
		while (i >= 0) begin
			if (addr < WPSEL_limit[i]) begin
				WPSEL_offset = WPSEL_delta[i] + ((addr - limit) >> WPSEL_shift[i]);
				i = -1;
			end
			else begin
				limit = WPSEL_limit[i];
				i = i + 1;
			end
		end
	end
	endfunction

	function WPSEL_protection;
		input [msbCOMD:lsbCOMD] command;
		input [msbMAIN:lsbMAIN] addr;
		reg [msbMAIN:lsbMAIN] mask;
		integer as, ae, i;
	begin
		case (command)
			cmdCE_1,
			cmdCE_2: begin
				as = 0; ae = WPSEL_offset(endMAIN | oriMAIN);
			end
			cmdBE32K: begin
				mask = endB32K;
				as = WPSEL_offset(addr & ~mask);
				ae = WPSEL_offset((addr & ~mask) | mask);
			end
			cmdBE: begin
				mask = endBLOK;
				as = WPSEL_offset(addr & ~mask);
				ae = WPSEL_offset((addr & ~mask) | mask);
			end
			cmdSE,
			cmdPP,
			cmd4PP: begin
				as = WPSEL_offset(addr); ae = as;
			end
			default: begin
				as = 0; ae = as - 1;
			end
		endcase
		WPSEL_protection = 0;
		for (i = as; i <= ae; i = i + 1) begin
			if (mxArray[oriDPBR + i] | mxArray[oriSPBR + i]) WPSEL_protection = 1;
		end
	end
	endfunction

	function integer tPP_calculator;
		input integer n;
		integer tmax;
	begin
		if (n >= endDATA) n = endDATA;
		tmax = tPP;
		if (FMD == 1) tmax = tPP_FMD;
		if (n == 1) begin
			tPP_calculator = tBP;
		end
		else begin
			tPP_calculator = tmax;
		end
	end
	endfunction

	task ithd_next;
		input integer othd;
		integer ithd;
	begin
		if (othd == `sizeTHRD) ithd = 1;
		else ithd = othd + 1;
		if (thdWIP[ithd] == 0) begin
			iThd = ithd; thdPRE[ithd] = othd;
		end
	end
	endtask

	task speed_check;
	input rising;
	realtime cycle;
	begin
		if (iPhase == phsIDLE || iPhase == phsINIT) disable speed_check;
		if (rising == 1) cycle = $realtime - risSCLK;
		else cycle = $realtime - falSCLK;

		if (cycle <= tcSCLK && cycle > 0) begin
			$write ("\n");
			$write ("Warning! Timing violation in command: %0s\n", strCOMD);
			$write ("\t\tSCLK period %0.2fns ", cycle);
			$write ("is short than %0.2fns (%0.0fMHz)\n", tcSCLK, fcSCLK);
			$write ("Time: %0.2f\n", $realtime);
		end
		if (rising == 1) risSCLK = $realtime;
		else falSCLK = $realtime;
	end
	endtask

	// Timing check
	specify
		$period (posedge inSCLK &&& ~inCS_b, tSCLK);
		$period (negedge inSCLK &&& ~inCS_b, tSCLK);
		$width  (posedge inSCLK &&& ~inCS_b, tCH);
		$width  (negedge inSCLK &&& ~inCS_b, tCL);
		$width  (posedge inCS_b &&& tcSHSL_R, tSHSL_R);
		$width  (posedge inCS_b &&& tcSHSL_W, tSHSL_W);
		$width  (posedge inCS_b &&& tcDP, (tDPDD + tDP));
		$period (posedge inSCLK &&& tcREAD, tRSCLK);
		$width  (posedge inSCLK &&& tcREAD, tCH_R);
		$width  (negedge inSCLK &&& tcREAD, tCL_R);
		$setup  (inSIO0 &&& ~inCS_b, posedge inSCLK &&& tcIN, tDVCH);
		$hold   (posedge inSCLK &&& tcIN, inSIO0 &&& ~inCS_b, tCHDX);
		$setup  (inSIO1 &&& ~inCS_b, posedge inSCLK &&& tcIN, tDVCH);
		$hold   (posedge inSCLK &&& tcIN, inSIO1 &&& ~inCS_b, tCHDX);
		$setup  (inSIO2 &&& ~inCS_b, posedge inSCLK &&& tcIN, tDVCH);
		$setup  (inSIO3 &&& ~inCS_b, posedge inSCLK &&& tcIN, tDVCH);
		$hold   (posedge inSCLK &&& tcIN, inSIO2 &&& ~inCS_b, tCHDX);
		$hold   (posedge inSCLK &&& tcIN, inSIO3 &&& ~inCS_b, tCHDX);
		$setup  (negedge inCS_b, posedge inSCLK &&& ~inCS_b, tSLCH);
		$hold   (posedge inSCLK &&& ~inCS_b, posedge inCS_b, tCHSH);
		$setup  (posedge inCS_b, posedge inSCLK &&& inCS_b, tSHCH);
		$hold   (posedge inSCLK &&& inCS_b, negedge inCS_b, tCHSL);
		$setup  (posedge inWP_b &&& ENWP, negedge inCS_b, tWHSL);
		$hold   (posedge inCS_b, negedge inWP_b &&& ENWP, tSHWL);
		$width  (negedge inRESET_b &&& ENRESET, tRLRH);
		$setup  (posedge inCS_b, negedge inRESET_b &&& ENRESET, tRS);
		$hold   (negedge inRESET_b &&& ENRESET, posedge inCS_b, tRH);
		$hold   (posedge inRESET_b &&& ENRESET, negedge inCS_b, tRHSL);
	endspecify


	function integer dummy_cycle;
		input [msbCOMD:lsbCOMD] command;
		integer idc;
	begin
		idc = mxArray[oriCREG][bitDC1:bitDC0];
		dummy_cycle = 0;
		case (command)
			cmdFASTREAD:  dummy_cycle = dcArray[0][idc];
			cmd2READ:     dummy_cycle = dcArray[1][idc];
			cmdDREAD:     dummy_cycle = dcArray[0][idc];
			cmd4READ:     dummy_cycle = dcArray[2][idc];
			cmdQREAD:     dummy_cycle = dcArray[0][idc];
			cmdW4READ:    dummy_cycle = msbDC04;
			cmdRDSFDP:    dummy_cycle = msbDC08;
		endcase
	end
	endfunction

	task dummy_speed;
		integer idc;
	begin
		idc = mxArray[oriCREG][bitDC1:bitDC0];
		fcSCLK = fSCLK; tcSCLK = tSCLK;
		case (regCOMD[iThd])
			cmdFASTREAD:  begin fcSCLK = fcArray[0][idc]; tcSCLK = tcArray[0][idc]; end
			cmd2READ:     begin fcSCLK = fcArray[1][idc]; tcSCLK = tcArray[1][idc]; end
			cmdDREAD:     begin fcSCLK = fcArray[0][idc]; tcSCLK = tcArray[0][idc]; end
			cmd4READ:     begin fcSCLK = fcArray[2][idc]; tcSCLK = tcArray[2][idc]; end
			cmdQREAD:     begin fcSCLK = fcArray[3][idc]; tcSCLK = tcArray[3][idc]; end
		endcase
	end
	endtask

	task set_strCOMD;
	begin
		case (regCOMD[iThd])
			cmd2READ:    strCOMD = "2READ";
			cmd4PP:      strCOMD = "4PP";
			cmd4READ:    strCOMD = "4READ";
			cmdBE:       strCOMD = "BE";
			cmdBE32K:    strCOMD = "BE32K";
			cmdCE_1:     strCOMD = "CE_1";
			cmdCE_2:     strCOMD = "CE_2";
			cmdDP:       strCOMD = "DP";
			cmdDREAD:    strCOMD = "DREAD";
			cmdENSO:     strCOMD = "ENSO";
			cmdEQIO:     strCOMD = "EQIO";
			cmdESSPB:    strCOMD = "ESSPB";
			cmdEXSO:     strCOMD = "EXSO";
			cmdFASTREAD: strCOMD = "FASTREAD";
			cmdFMEN:     strCOMD = "FMEN";
			cmdGBLK:     strCOMD = "GBLK";
			cmdGBULK:    strCOMD = "GBULK";
			cmdNOP:      strCOMD = "NOP";
			cmdPP:       strCOMD = "PP";
			cmdQPIID:    strCOMD = "QPIID";
			cmdQREAD:    strCOMD = "QREAD";
			cmdRDCR:     strCOMD = "RDCR";
			cmdRDDPB:    strCOMD = "RDDPB";
			cmdRDFMSR:   strCOMD = "RDFMSR";
			cmdRDID:     strCOMD = "RDID";
			cmdRDLR:     strCOMD = "RDLR";
			cmdRDSCUR:   strCOMD = "RDSCUR";
			cmdRDSFDP:   strCOMD = "RDSFDP";
			cmdRDSPB:    strCOMD = "RDSPB";
			cmdRDSR:     strCOMD = "RDSR";
			cmdREAD:     strCOMD = "READ";
			cmdREMS:     strCOMD = "REMS";
			cmdRES:      strCOMD = "RES";
			cmdRSM_1:    strCOMD = "RSM_1";
			cmdRSM_2:    strCOMD = "RSM_2";
			cmdRST:      strCOMD = "RST";
			cmdRSTEN:    strCOMD = "RSTEN";
			cmdRSTQIO:   strCOMD = "RSTQIO";
			cmdSBL:      strCOMD = "SBL";
			cmdSE:       strCOMD = "SE";
			cmdSUS_1:    strCOMD = "SUS_1";
			cmdSUS_2:    strCOMD = "SUS_2";
			cmdW4READ:   strCOMD = "W4READ";
			cmdWPSEL:    strCOMD = "WPSEL";
			cmdWRDI:     strCOMD = "WRDI";
			cmdWRDPB:    strCOMD = "WRDPB";
			cmdWREN:     strCOMD = "WREN";
			cmdWRLR:     strCOMD = "WRLR";
			cmdWRSCUR:   strCOMD = "WRSCUR";
			cmdWRSPB:    strCOMD = "WRSPB";
			cmdWRSR:     strCOMD = "WRSR";
			default:     strCOMD = "?cmd?";
		endcase
	end
	endtask
endmodule
