* rmdir - remove directory
*
* Itagaki Fumihiko  8-Jul-91  Create.
* 1.0
* Itagaki Fumihiko 22-Aug-92  strip_excessive_slashes
* Itagaki Fumihiko 22-Aug-92  -p で [?:][/] を無視する
* Itagaki Fumihiko 24-Sep-92  ドライブを予め検査するのはやめた。
*                             どうしたって完全にはチェックできないので。
* 1.1
* Itagaki Fumihiko 29-Sep-92  読み込み専用やシステム属性が付いていても削除するようにした。
* 1.2
*
* Usage: rmdir [ -ps ] [ - ] <パス名> ...

.include doscall.h
.include error.h
.include stat.h
.include chrcode.h

.xref DecodeHUPAIR
.xref issjis
.xref strlen
.xref strfor1
.xref strip_excessive_slashes
.xref headtail

STACKSIZE	equ	256

.text
start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	stack_bottom(pc),a7		*  A7 := スタックの底
		DOS	_GETPDB
		movea.l	d0,a0				*  A0 : PDBアドレス
		move.l	a7,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
	*  引数をデコードし，解釈する
	*
		lea	1(a2),a0			*  A0 := コマンドラインの文字列の先頭アドレス
		bsr	strlen				*  D0.L := コマンドラインの文字列の長さ
		addq.l	#1,d0
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := 引数並び格納エリアの先頭アドレス
		bsr	DecodeHUPAIR			*  引数をデコードする
		movea.l	a1,a0				*  A0 : 引数ポインタ
		move.l	d0,d7				*  D7.L : 引数カウンタ
		moveq	#0,d5				*  D5.L : bit0:-p, bit1:-s
decode_opt_loop1:
		tst.l	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a0)
		bne	decode_opt_done

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		beq	decode_opt_done
decode_opt_loop2:
		moveq	#0,d1
		cmp.b	#'p',d0
		beq	set_option

		moveq	#1,d2
		cmp.b	#'s',d0
		bne	bad_option
set_option:
		bset	d1,d5
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
		tst.l	d7
		beq	too_few_args

		moveq	#0,d6				*  D6.W : エラー・コード
loop:
		movea.l	a0,a2
		bsr	strfor1
		exg	a0,a2				*  A2 : 次の引数の先頭アドレス

		bsr	strip_excessive_slashes
		movea.l	a0,a3
		bsr	strfor1
		exg	a0,a3
		move.b	-(a3),d1			*  A3 : この引数の末尾アドレス

		bsr	do_rmdir
		bmi	fail_2

		btst	#0,d5
		beq	next

	*  -p が指定されている ... 明示的な親ディレクトリも消す
	*                          ただしドライブと / は除外

		movea.l	a0,a4				*  A4 : [?:][/] をスキップした先頭
		tst.b	(a4)
		beq	rmdir_p_start

		cmpi.b	#':',1(a4)
		bne	rmdir_p_no_drive

		addq.l	#2,a4
rmdir_p_no_drive:
		cmpi.b	#'/',(a4)
		beq	rmdir_p_skip_root

		cmpi.b	#'\',(a4)
		bne	rmdir_p_start
rmdir_p_skip_root:
		addq.l	#1,a4
rmdir_p_start:
rmdir_p_loop:
		exg	a0,a4
		bsr	headtail
		exg	a0,a4
		move.b	d1,(a3)
		tst.l	d0
		beq	whole_path_removed

		movea.l	a1,a3
		move.b	-(a3),d1
		clr.b	(a3)
		bsr	do_rmdir
		bpl	rmdir_p_loop

		move.b	d1,(a3)
fail_2:
		moveq	#2,d6
		btst	#0,d5
		bne	fail_p
		bra	perror_normal_and_next

whole_path_removed:
		moveq	#0,d0				*  means 'whole path removed'
fail_p:
		btst	#1,d5
		bne	next

		tst.l	d0
		beq	perror_normal_and_next

		bsr	werror_myname
		bsr	werror_name_colon
		clr.b	(a3)
		bsr	werror
		lea	msg_not_removed(pc),a0
		bsr	werror
		bra	perror_and_next

perror_normal_and_next:
		bsr	werror_myname
		bsr	werror_name_colon
perror_and_next:
		bsr	perror
next:
		movea.l	a2,a0
		subq.l	#1,d7
		bne	loop
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2

bad_option:
		moveq	#1,d1
		tst.b	(a0)
		beq	bad_option_1

		bsr	issjis
		bne	bad_option_1

		moveq	#2,d1
bad_option_1:
		move.l	d1,-(a7)
		pea	-1(a0)
		move.w	#2,-(a7)
		bsr	werror_myname
		lea	msg_illegal_option(pc),a0
		bsr	werror
		DOS	_WRITE
		lea	10(a7),a7
		bra	usage

too_few_args:
		bsr	werror_myname
		lea	msg_too_few_args(pc),a0
		bsr	werror
usage:
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d6
		bra	exit_program
*****************************************************************
insufficient_memory:
		bsr	werror_myname
		lea	msg_no_memory(pc),a0
		bsr	werror
		moveq	#3,d6
		bra	exit_program
*****************************************************************
werror_name_colon:
		move.l	a0,-(a7)
		bsr	werror
		lea	msg_colon(pc),a0
		bra	perror_5
*****************************************************************
perror:
		move.l	a0,-(a7)
		lea	msg_whole_path_removed(pc),a0
		tst.l	d0
		bpl	perror_4

		not.l	d0				*  -1 -> 0, -2 -> 1, ...
		cmp.l	#25,d0
		bls	perror_2

		moveq	#0,d0
perror_2:
		lea	perror_table(pc),a0
		lsl.l	#1,d0
		move.w	(a0,d0.l),d0
		lea	sys_errmsgs(pc),a0
		lea	(a0,d0.w),a0
perror_4:
		bsr	werror
		lea	msg_newline(pc),a0
perror_5:
		bsr	werror
		movea.l	(a7)+,a0
		rts
*****************************************************************
werror_myname:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		rts
*****************************************************************
werror:
		movea.l	a0,a1
werror_1:
		tst.b	(a1)+
		bne	werror_1

		subq.l	#1,a1
		move.l	d0,-(a7)
		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		move.l	(a7)+,d0
		rts
*****************************************************************
do_rmdir:
		move.l	d1,-(a7)
		bsr	lgetmode
		move.l	d0,d1
		bmi	do_rmdir_return

		moveq	#ENODIR,d0
		btst	#MODEBIT_VOL,d1
		bne	do_rmdir_return

		btst	#MODEBIT_DIR,d1
		beq	do_rmdir_return

		btst	#MODEVAL_RDO,d1
		bne	do_rmdir_1

		btst	#MODEVAL_SYS,d1
		bne	do_rmdir_1

		moveq	#-1,d1
		bra	do_rmdir_2

do_rmdir_1:
		moveq	#MODEVAL_DIR,d0
		bsr	lchmod
do_rmdir_2:
		move.l	a0,-(a7)
		DOS	_RMDIR
		addq.l	#4,a7
		tst.l	d0
		bpl	do_rmdir_return

		tst.l	d1
		bmi	do_rmdir_return

		exg	d0,d1
		bsr	lchmod
		exg	d0,d1
do_rmdir_return:
		move.l	(a7)+,d1
		tst.l	d0
		rts
*****************************************************************
lgetmode:
		moveq	#-1,d0
lchmod:
		move.w	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_CHMOD
		addq.l	#6,a7
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## rmdir 1.2 ##  Copyright(C)1992 by Itagaki Fumihiko',0

.even
perror_table:
	dc.w	msg_err-sys_errmsgs			*   0 ( -1)
	dc.w	msg_nodir-sys_errmsgs			*   1 ( -2)  ENOFILE
	dc.w	msg_notdir-sys_errmsgs			*   2 ( -3)  ENODIR
	dc.w	msg_err-sys_errmsgs			*   3 ( -4)
	dc.w	msg_err-sys_errmsgs			*   4 ( -5)
	dc.w	msg_err-sys_errmsgs			*   5 ( -6)
	dc.w	msg_err-sys_errmsgs			*   6 ( -7)
	dc.w	msg_err-sys_errmsgs			*   7 ( -8)
	dc.w	msg_err-sys_errmsgs			*   8 ( -9)
	dc.w	msg_err-sys_errmsgs			*   9 (-10)
	dc.w	msg_err-sys_errmsgs			*  10 (-11)
	dc.w	msg_err-sys_errmsgs			*  11 (-12)
	dc.w	msg_bad_filename-sys_errmsgs		*  12 (-13)
	dc.w	msg_err-sys_errmsgs			*  13 (-14)
	dc.w	msg_bad_drive-sys_errmsgs		*  14 (-15)
	dc.w	msg_current-sys_errmsgs			*  15 (-16)
	dc.w	msg_err-sys_errmsgs			*  16 (-17)
	dc.w	msg_err-sys_errmsgs			*  17 (-18)
	dc.w	msg_err-sys_errmsgs			*  18 (-19)
	dc.w	msg_err-sys_errmsgs			*  19 (-20)
	dc.w	msg_not_empty-sys_errmsgs		*  20 (-21)
	dc.w	msg_err-sys_errmsgs			*  21 (-22)
	dc.w	msg_err-sys_errmsgs			*  22 (-23)
	dc.w	msg_err-sys_errmsgs			*  23 (-24)
	dc.w	msg_err-sys_errmsgs			*  24 (-25)
	dc.w	msg_err-sys_errmsgs			*  25 (-26)

sys_errmsgs:
msg_nodir:		dc.b	'このようなディレクトリはありません',0
msg_notdir:		dc.b	'ディレクトリではありません',0
msg_bad_filename:	dc.b	'名前が無効です',0
msg_bad_drive:		dc.b	'ドライブの指定が無効です',0
msg_current:		dc.b	'カレント・ディレクトリですので削除できません',0
msg_not_empty:		dc.b	'ディレクトリが空でないので'
msg_err:		dc.b	'削除できません',0
msg_not_removed:	dc.b	' は削除しませんでした; ',0
msg_whole_path_removed:	dc.b	'まるごと削除しました',0

msg_semicolon:		dc.b	'; ',0
msg_myname:		dc.b	'rmdir'
msg_colon:		dc.b	': ',0
msg_no_memory:		dc.b	'メモリが足りません',CR,LF,0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_too_few_args:	dc.b	'引数が足りません',0
msg_usage:		dc.b	CR,LF,'使用法:  rmdir [-ps] [-] <パス名> ...'
msg_newline:		dc.b	CR,LF,0
*****************************************************************
.bss
.even
		ds.b	STACKSIZE
.even
stack_bottom:
*****************************************************************

.end start
