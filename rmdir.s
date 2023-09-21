* rmdir - remove directory
*
* Itagaki Fumihiko  8-Jul-91  Create.
*
* Usage: rmdir [ -ps ] [ - ] <パス名> ...

.include doscall.h
.include error.h
.include chrcode.h

.xref DecodeHUPAIR
.xref strlen
.xref strfor1
.xref headtail
.xref drvchkp

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
		beq	set_option

		bsr	werror_myname
		lea	msg_illegal_option(pc),a0
		bsr	werror
		move.w	d0,-(a7)
		move.l	#1,-(a7)
		pea	5(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	12(a7),a7
		bra	usage

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
		exg	a0,a2
		movea.l	a2,a3
		move.b	-(a3),d1

		bsr	drvchkp
		bmi	fail_2

		bsr	do_rmdir
		bmi	fail_2

		btst	#0,d5
		beq	next

	*  -pが指定されている ... 明示的な親ディレクトリも消す

rmdir_p_loop:
		bsr	headtail
		move.b	d1,(a3)
		moveq	#0,d0				*  means 'whole path removed'
		cmpa.l	a0,a1
		beq	fail_p				*  whole_path_removed

		move.b	-(a1),d1
		cmp.b	#'/',d1
		beq	rmdir_p_more

		cmp.b	#'\',d1
		bne	fail_p				*  whole_path_removed
rmdir_p_more:
		movea.l	a1,a3
		clr.b	(a3)
		bsr	do_rmdir
		bpl	rmdir_p_loop

		move.b	d1,(a3)
fail_2:
		moveq	#2,d6
		btst	#0,d5
		beq	perror_normal_and_next
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

		cmp.l	#256,d0
		blo	perror_1

		sub.l	#256,d0
		cmp.l	#4,d0
		bhi	perror_1

		lea	perror_table_2(pc),a0
		bra	perror_3

perror_1:
		moveq	#25,d0
perror_2:
		lea	perror_table(pc),a0
perror_3:
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
		move.l	a0,-(a7)
		DOS	_RMDIR
		addq.l	#4,a7
		cmp.l	#ENODIR,d0
		bne	do_rmdir_return

		move.w	#-1,-(a7)
		move.l	a0,-(a7)
		DOS	_CHMOD
		addq.l	#6,a7
		tst.l	d0
		bmi	do_rmdir_nofile

		moveq	#ENODIR,d0
		bra	do_rmdir_return

do_rmdir_nofile:
		moveq	#ENOFILE,d0
do_rmdir_return:
		tst.l	d0
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## rmdir 1.0 ##  Copyright(C)1992 by Itagaki Fumihiko',0

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
	dc.w	msg_write_disabled-sys_errmsgs		*  18 (-19)
	dc.w	msg_err-sys_errmsgs			*  19 (-20)
	dc.w	msg_not_empty-sys_errmsgs		*  20 (-21)
	dc.w	msg_err-sys_errmsgs			*  21 (-22)
	dc.w	msg_err-sys_errmsgs			*  22 (-23)
	dc.w	msg_err-sys_errmsgs			*  23 (-24)
	dc.w	msg_err-sys_errmsgs			*  24 (-25)
	dc.w	msg_err-sys_errmsgs			*  25 (-26)
.even
perror_table_2:
	dc.w	msg_bad_drivename-sys_errmsgs		* 256 (-257)
	dc.w	msg_no_drive-sys_errmsgs		* 257 (-258)
	dc.w	msg_no_media_in_drive-sys_errmsgs	* 258 (-259)
	dc.w	msg_media_set_miss-sys_errmsgs		* 259 (-260)
	dc.w	msg_drive_not_ready-sys_errmsgs		* 260 (-261)

sys_errmsgs:
msg_nodir:		dc.b	'このようなディレクトリはありません',0
msg_notdir:		dc.b	'ディレクトリではありません',0
msg_bad_filename:	dc.b	'名前が無効です',0
msg_bad_drive:		dc.b	'ドライブの指定が無効です',0
msg_current:		dc.b	'カレント・ディレクトリですので削除できません',0
msg_write_disabled:	dc.b	'削除は許可されていません',0
msg_not_empty:		dc.b	'ディレクトリが空でないので削除できません',0
msg_bad_drivename:	dc.b	'ドライブ名が無効です',0
msg_no_drive:		dc.b	'ドライブがありません',0
msg_no_media_in_drive:	dc.b	'ドライブにメディアがセットされていません',0
msg_media_set_miss:	dc.b	'ドライブにメディアが正しくセットされていません',0
msg_drive_not_ready:	dc.b	'ドライブの準備ができていません',0
msg_err:		dc.b	'削除できませんでした',0
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
