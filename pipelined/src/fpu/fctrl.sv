`include "wally-config.vh"

module fctrl (
  input  logic [6:0] Funct7D,   // bits 31:25 of instruction - may contain percision
  input  logic [6:0] OpD,       // bits 6:0 of instruction
  input  logic [4:0] Rs2D,      // bits 24:20 of instruction
  input  logic [2:0] Funct3D,   // bits 14:12 of instruction - may contain rounding mode
  input  logic [2:0] FRM_REGW,  // rounding mode from CSR
  input  logic [1:0] STATUS_FS, // is FPU enabled?
  output logic       IllegalFPUInstrD, // Is the instruction an illegal fpu instruction
  output logic       FRegWriteD,  // FP register write enable
  output logic       FDivStartD,  // Start division or squareroot
  output logic [1:0] FResSelD, // select result to be written to fp register
  output logic [2:0] FOpCtrlD,    // chooses which opperation to do - specifics shown at bottom of module and in each unit
  output logic [1:0] PostProcSelD, 
  output logic [`FMTBITS-1:0] FmtD,        // precision - single-0 double-1
  output logic [2:0] FrmD,        // rounding mode 000 = rount to nearest, ties to even   001 = round twords zero  010 = round down  011 = round up  100 = round to nearest, ties to max magnitude
  output logic       FWriteIntD   // is the result written to the integer register
  );

  `define FCTRLW 11
  logic [`FCTRLW-1:0] ControlsD;
  //*** will putting x for don't cares reduce area in synthisis???
  // FPU Instruction Decoder
  always_comb
    if (STATUS_FS == 2'b00) // FPU instructions are illegal when FPU is disabled
      ControlsD = `FCTRLW'b0_0_00_00_000_0_1;
    else case(OpD)
    // FRegWrite_FWriteInt_FResSel_PostProcSel_FOpCtrl_FDivStart_IllegalFPUInstr
      7'b0000111: case(Funct3D)
                    3'b010:  ControlsD = `FCTRLW'b1_0_10_00_000_0_0; // flw
                    3'b011:  ControlsD = `FCTRLW'b1_0_10_00_000_0_0; // fld
                    default: ControlsD = `FCTRLW'b0_0_00_00_000_0_1; // non-implemented instruction
                  endcase
      7'b0100111: case(Funct3D)
                    3'b010:  ControlsD = `FCTRLW'b0_0_00_00_000_0_0; // fsw
                    3'b011:  ControlsD = `FCTRLW'b0_0_00_00_000_0_0; // fsd
                    default: ControlsD = `FCTRLW'b0_0_00_00_000_0_1; // non-implemented instruction
                  endcase
      7'b1000011:   ControlsD = `FCTRLW'b1_0_01_10_000_0_0; // fmadd
      7'b1000111:   ControlsD = `FCTRLW'b1_0_01_10_001_0_0; // fmsub
      7'b1001011:   ControlsD = `FCTRLW'b1_0_01_10_010_0_0; // fnmsub
      7'b1001111:   ControlsD = `FCTRLW'b1_0_01_10_011_0_0; // fnmadd
      7'b1010011: casez(Funct7D)
                    7'b00000??: ControlsD = `FCTRLW'b1_0_01_10_110_0_0; // fadd
                    7'b00001??: ControlsD = `FCTRLW'b1_0_01_10_111_0_0; // fsub
                    7'b00010??: ControlsD = `FCTRLW'b1_0_01_10_100_0_0; // fmul
                    7'b00011??: ControlsD = `FCTRLW'b1_0_01_01_000_1_0; // fdiv
                    7'b01011??: ControlsD = `FCTRLW'b1_0_01_01_001_1_0; // fsqrt
                    7'b00100??: case(Funct3D)
                                  3'b000:  ControlsD = `FCTRLW'b1_0_00_00_000_0_0; // fsgnj
                                  3'b001:  ControlsD = `FCTRLW'b1_0_00_00_001_0_0; // fsgnjn
                                  3'b010:  ControlsD = `FCTRLW'b1_0_00_00_010_0_0; // fsgnjx
                                  default: ControlsD = `FCTRLW'b0_0_00_00_000_0_1; // non-implemented instruction
                                endcase
                    7'b00101??: case(Funct3D)
                                  3'b000:  ControlsD = `FCTRLW'b1_0_00_00_110_0_0; // fmin
                                  3'b001:  ControlsD = `FCTRLW'b1_0_00_00_101_0_0; // fmax
                                  default: ControlsD = `FCTRLW'b0_0_00_00_000_0_1; // non-implemented instruction
                                endcase
                    7'b10100??: case(Funct3D)
                                  3'b010:  ControlsD = `FCTRLW'b0_1_00_00_010_0_0; // feq
                                  3'b001:  ControlsD = `FCTRLW'b0_1_00_00_001_0_0; // flt
                                  3'b000:  ControlsD = `FCTRLW'b0_1_00_00_011_0_0; // fle
                                  default: ControlsD = `FCTRLW'b0_0_00_00_000__0_1; // non-implemented instruction
                                endcase
                    7'b11100??: if (Funct3D == 3'b001)          ControlsD = `FCTRLW'b0_1_10_00_000_0_0; // fclass
                                else if (Funct3D[1:0] == 2'b00) ControlsD = `FCTRLW'b0_1_11_00_000_0_0; // fmv.x.w   to int reg
                                else if (Funct3D[1:0] == 2'b01) ControlsD = `FCTRLW'b0_1_11_00_000_0_0; // fmv.x.d   to int reg
                                else                            ControlsD = `FCTRLW'b0_0_00_00_000_0_1; // non-implemented instruction
                    7'b1101000: case(Rs2D[1:0])
                                  2'b00:    ControlsD = `FCTRLW'b1_0_01_00_101_0_0; // fcvt.s.w   w->s
                                  2'b01:    ControlsD = `FCTRLW'b1_0_01_00_100_0_0; // fcvt.s.wu wu->s
                                  2'b10:    ControlsD = `FCTRLW'b1_0_01_00_111_0_0; // fcvt.s.l   l->s
                                  2'b11:    ControlsD = `FCTRLW'b1_0_01_00_110_0_0; // fcvt.s.lu lu->s
                                endcase
                    7'b1100000: case(Rs2D[1:0])
                                  2'b00:    ControlsD = `FCTRLW'b0_1_01_00_001_0_0; // fcvt.w.s   s->w
                                  2'b01:    ControlsD = `FCTRLW'b0_1_01_00_000_0_0; // fcvt.wu.s  s->wu
                                  2'b10:    ControlsD = `FCTRLW'b0_1_01_00_011_0_0; // fcvt.l.s   s->l
                                  2'b11:    ControlsD = `FCTRLW'b0_1_01_00_010_0_0; // fcvt.lu.s  s->lu
                                endcase
                    7'b1111000: ControlsD = `FCTRLW'b1_0_00_00_011_0_0; // fmv.w.x   to fp reg
                    7'b0100000: ControlsD = `FCTRLW'b1_0_01_00_000_0_0; // fcvt.s.d
                    7'b1101001: case(Rs2D[1:0])
                                  2'b00:    ControlsD = `FCTRLW'b1_0_01_00_101_0_0; // fcvt.d.w   w->d
                                  2'b01:    ControlsD = `FCTRLW'b1_0_01_00_100_0_0; // fcvt.d.wu wu->d
                                  2'b10:    ControlsD = `FCTRLW'b1_0_01_00_111_0_0; // fcvt.d.l   l->d
                                  2'b11:    ControlsD = `FCTRLW'b1_0_01_00_110_0_0; // fcvt.d.lu lu->d
                                endcase
                    7'b1100001: case(Rs2D[1:0])
                                  2'b00:    ControlsD = `FCTRLW'b0_1_01_00_001_0_0; // fcvt.w.d   d->w
                                  2'b01:    ControlsD = `FCTRLW'b0_1_01_00_000_0_0; // fcvt.wu.d  d->wu
                                  2'b10:    ControlsD = `FCTRLW'b0_1_01_00_011_0_0; // fcvt.l.d   d->l
                                  2'b11:    ControlsD = `FCTRLW'b0_1_01_00_010_0_0; // fcvt.lu.d  d->lu
                                endcase
                    7'b1111001: ControlsD = `FCTRLW'b1_0_00_00_011_0_0; // fmv.d.x   to fp reg
                    7'b0100001: ControlsD = `FCTRLW'b1_0_01_00_001_0_0; // fcvt.d.s
                    default:    ControlsD = `FCTRLW'b0_0_00_00_000_0_1; // non-implemented instruction
                  endcase
      default:      ControlsD = `FCTRLW'b0_0_00_00_000_0_1; // non-implemented instruction
    endcase

  // unswizzle control bits
  assign {FRegWriteD, FWriteIntD, FResSelD, PostProcSelD, FOpCtrlD, FDivStartD, IllegalFPUInstrD} = ControlsD;
  
  // rounding modes:
  //    000 - round to nearest, ties to even
  //    001 - round twords 0 - round to min magnitude
  //    010 - round down - round twords negitive infinity
  //    011 - round up - round twords positive infinity
  //    100 - round to nearest, ties to max magnitude - round to nearest, ties away from zero
  //    111 - dynamic - choose FRM_REGW as rounding mode
  assign FrmD = &Funct3D ? FRM_REGW : Funct3D;

  // Precision
  //    0-single
  //    1-double
  
    if (`FPSIZES == 1)
      assign FmtD = 0;
    else if (`FPSIZES == 2)begin
      logic [1:0] FmtTmp;
      assign FmtTmp = (FResSelD == 2'b10)&~FWriteIntD ? {~Funct3D[1], ~(Funct3D[1]^Funct3D[0])} : ((Funct7D[6:3] == 4'b0100)&OpD[4]) ? Rs2D[1:0] : Funct7D[1:0];
      assign FmtD = (`FMT == FmtTmp);
    end
    else if (`FPSIZES == 3|`FPSIZES == 4)
      assign FmtD = (FResSelD == 2'b10)&~FWriteIntD ? {~Funct3D[1], ~(Funct3D[1]^Funct3D[0])} : ((Funct7D[6:3] == 4'b0100)&OpD[4]) ? Rs2D[1:0] : Funct7D[1:0];

//  Final Res Sel:
//        fp      int
//  00  other     cmp
//  01  postproc  cvt
//  10  store     class
//  11            mv

//  post processing Sel:
//  00  cvt
//  01  div
//  10  fma

//  Other Sel:
//    Ctrl signal = {FOpCtrl[2], &FOpctrl[1:0]}
//        000 - sign            00
//        001 - negate sign     00
//        010 - xor sign        00
//        011 - mv to fp        01
//        110 - min             10
//        101 - max             10

//  OpCtrl:
//    Fma: {not multiply-add?, negate prod?, negate Z?}
//        000 - fmadd
//        001 - fmsub
//        010 - fnmsub
//        011 - fnmadd
//        100 - mul
//        110 - add
//        111 - sub
//    Div: 
//        0 - ???
//        1 - ???
//    Cvt Int: {Int to Fp?, 64 bit int?, signed int?}
//    Cvt Fp: output format
//        10 - to half
//        00 - to single
//        01 - to double
//        11 - to quad
//    Cmp: {equal?, less than?}
//        010 - eq
//        001 - lt
//        011 - le
//        110 - min
//        101 - max
//    Sgn:
//        00 - sign
//        01 - negate sign
//        10 - xor sign
    

endmodule
