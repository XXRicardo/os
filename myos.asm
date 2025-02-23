; -----------------------------------------------------------------
; TASK4
; 编译方法：nasm task4.asm -o task4.com
; -----------------------------------------------------------------

%include "pm.inc"

; 4个任务页目录地址
PageDirBase0		equ	200000h	; 页目录开始地址:	2M
PageTblBase0		equ	201000h	; 页表开始地址:		2M +  4K
PageDirBase1		equ	210000h	; 页目录开始地址:	2M + 64K
PageTblBase1		equ	211000h	; 页表开始地址:		2M + 64K + 4K
PageDirBase2		equ	220000h	; 页目录开始地址:	2M + 128K
PageTblBase2		equ	221000h	; 页表开始地址:		2M + 128K + 4K
PageDirBase3		equ	230000h	; 页目录开始地址:	2M + 192K
PageTblBase3		equ	231000h	; 页表开始地址:		2M + 192K + 4K

org 0100h
    jmp LABEL_BEGIN


; GDT
[SECTION .gdt]
;                                      段基址,       段界限     , 属性
LABEL_GDT:		Descriptor	       0,                 0, 0										; 空描述符
LABEL_DESC_NORMAL:	Descriptor	       0,            0ffffh, DA_DRW								; Normal 描述符
LABEL_DESC_FLAT_C:	Descriptor             0,           0fffffh, DA_CR | DA_32 | DA_LIMIT_4K	; 0 ~ 4G
LABEL_DESC_FLAT_RW:	Descriptor             0,           0fffffh, DA_DRW | DA_LIMIT_4K			; 0 ~ 4G
LABEL_DESC_CODE32:	Descriptor	       0,  SegCode32Len - 1, DA_CR | DA_32						; 非一致代码段, 32
LABEL_DESC_CODE16:	Descriptor	       0,            0ffffh, DA_C								; 非一致代码段, 16
LABEL_DESC_DATA:	Descriptor	       0,	DataLen - 1, DA_DRW									; Data
LABEL_DESC_STACK:	Descriptor	       0,        TopOfStack, DA_DRWA | DA_32					; Stack, 32 位
LABEL_DESC_VIDEO:	Descriptor	 0B8000h,            0ffffh, DA_DRW + DA_DPL3					; 显存首地址
; TSS
LABEL_DESC_TSS0: 	Descriptor 			0,          TSS0Len-1, DA_386TSS	   ;TSS
LABEL_DESC_TSS1: 	Descriptor 			0,          TSS1Len-1, DA_386TSS	   ;TSS
LABEL_DESC_TSS2: 	Descriptor 			0,          TSS2Len-1, DA_386TSS	   ;TSS
LABEL_DESC_TSS3: 	Descriptor 			0,          TSS3Len-1, DA_386TSS	   ;TSS

; 四个任务段
LABEL_TASK0_DESC_LDT:    Descriptor         0,   TASK0LDTLen - 1, DA_LDT
LABEL_TASK1_DESC_LDT:    Descriptor         0,   TASK1LDTLen - 1, DA_LDT
LABEL_TASK2_DESC_LDT:    Descriptor         0,   TASK2LDTLen - 1, DA_LDT
LABEL_TASK3_DESC_LDT:    Descriptor         0,   TASK3LDTLen - 1, DA_LDT

; GDT 结束
GdtLen		equ	$ - LABEL_GDT	; GDT长度
GdtPtr		dw	GdtLen - 1	; GDT界限
		dd	0		; GDT基地址

; GDT 选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorFlatC		equ	LABEL_DESC_FLAT_C	- LABEL_GDT
SelectorFlatRW		equ	LABEL_DESC_FLAT_RW	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
; 四个任务段选择子
SelectorTSS0        equ LABEL_DESC_TSS0     		- LABEL_GDT
SelectorTSS1        equ LABEL_DESC_TSS1     		- LABEL_GDT
SelectorTSS2        equ LABEL_DESC_TSS2     		- LABEL_GDT
SelectorTSS3        equ LABEL_DESC_TSS3     		- LABEL_GDT
SelectorLDT0        equ LABEL_TASK0_DESC_LDT   	- LABEL_GDT
SelectorLDT1        equ LABEL_TASK1_DESC_LDT    - LABEL_GDT
SelectorLDT2        equ LABEL_TASK2_DESC_LDT    - LABEL_GDT
SelectorLDT3        equ LABEL_TASK3_DESC_LDT 	- LABEL_GDT
; END of [SECTION .gdt]


; LDT 和任务段定义
; ---------------------------------------------------------------------------------------------
; 定义任务
DefineTask 0, "VERY", 20, 0Ch
DefineTask 1, "LOVE", 20, 0Fh
DefineTask 2, "HUST", 20, 0Ch
DefineTask 3, "MRSU", 20, 0Fh
; END of LDT 和任务段定义


; IDT
; ---------------------------------------------------------------------------------------------
[SECTION .idt]
ALIGN	32
[BITS	32]
LABEL_IDT:
; 门                          目标选择子,            偏移, DCount, 属性
%rep 32
				Gate	SelectorCode32, SpuriousHandler,      0, DA_386IGate
%endrep
.020h:			Gate	SelectorCode32,    ClockHandler,      0, DA_386IGate
%rep 95
				Gate	SelectorCode32, SpuriousHandler,      0, DA_386IGate
%endrep
.080h:			Gate	SelectorCode32,  UserIntHandler,      0, DA_386IGate

IdtLen		equ	$ - LABEL_IDT	; IDT 长度
IdtPtr		dw	IdtLen - 1		; IDT 段界限
			dd	0				; IDT 基地址, 待设置
; END of [SECTION .idt]



; 数据段
; ---------------------------------------------------------------------------------------------
[SECTION .data1]	 ; 数据段
ALIGN	32
[BITS	32]
LABEL_DATA:
; 实模式下使用这些符号
; 字符串
_szPMMessage:			db	"In Protect Mode now. ^-^", 0Ah, 0Ah, 0	; 进入保护模式后显示此字符串
_szMemChkTitle:			db	"BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0	; 进入保护模式后显示此字符串
_szRAMSize			db	"RAM size:", 0
_szReturn			db	0Ah, 0
_szReadyMessage:			db	"Ready", 0
; 变量
_wSPValueInRealMode		dw	0
_dwMCRNumber:			dd	0	; Memory Check Result
_dwDispPos:			dd	(80 * 6 + 0) * 2	; 屏幕第 6 行, 第 0 列。
_dwMemSize:			dd	0
_ARDStruct:			; Address Range Descriptor Structure
	_dwBaseAddrLow:		dd	0
	_dwBaseAddrHigh:	dd	0
	_dwLengthLow:		dd	0
	_dwLengthHigh:		dd	0
	_dwType:		dd	0
_PageTableNumber:		dd	0
_SavedIDTR:			dd	0	; 用于保存 IDTR
				dd	0
_SavedIMREG:			db	0	; 中断屏蔽寄存器值
_MemChkBuf:	times	256	db	0

%define tickTimes  30;
_RunningTask:			dd	0
_TaskPriority:			dd	16*tickTimes, 10*tickTimes, 8*tickTimes, 6*tickTimes
_LeftTicks:			dd	0, 0, 0, 0

; 保护模式下使用这些符号
szPMMessage		equ	_szPMMessage	- $$
szMemChkTitle		equ	_szMemChkTitle	- $$
szRAMSize		equ	_szRAMSize	- $$
szReturn		equ	_szReturn	- $$
szReadyMessage  equ _szReadyMessage - $$
dwDispPos		equ	_dwDispPos	- $$
dwMemSize		equ	_dwMemSize	- $$
dwMCRNumber		equ	_dwMCRNumber	- $$
ARDStruct		equ	_ARDStruct	- $$
	dwBaseAddrLow	equ	_dwBaseAddrLow	- $$
	dwBaseAddrHigh	equ	_dwBaseAddrHigh	- $$
	dwLengthLow	equ	_dwLengthLow	- $$
	dwLengthHigh	equ	_dwLengthHigh	- $$
	dwType		equ	_dwType		- $$
MemChkBuf		equ	_MemChkBuf	- $$
SavedIDTR		equ	_SavedIDTR	- $$
SavedIMREG		equ	_SavedIMREG	- $$
PageTableNumber		equ	_PageTableNumber- $$
; 任务相关变量
RunningTask     equ _RunningTask - $$
TaskPriority    equ _TaskPriority - $$
LeftTicks       equ _LeftTicks - $$
DataLen			equ	$ - LABEL_DATA
; END of [SECTION .data1]

; 全局堆栈段
; ---------------------------------------------------------------------------------------------
[SECTION .gs]
ALIGN	32
[BITS	32]
LABEL_STACK:
	times 512 db 0

TopOfStack	equ	$ - LABEL_STACK - 1
; END of [SECTION .gs]


; 16位代码段
; ---------------------------------------------------------------------------------------------
[SECTION .s16]
[BITS	16]
LABEL_BEGIN:
	; 准备工作
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h
	mov	[LABEL_GO_BACK_TO_REAL+3], ax
	mov	[_wSPValueInRealMode], sp
	; 得到内存数
	mov	ebx, 0
	mov	di, _MemChkBuf
.loop:
	mov	eax, 0E820h
	mov	ecx, 20
	mov	edx, 0534D4150h
	int	15h
	jc	LABEL_MEM_CHK_FAIL
	add	di, 20
	inc	dword [_dwMCRNumber]
	cmp	ebx, 0
	jne	.loop
	jmp	LABEL_MEM_CHK_OK
LABEL_MEM_CHK_FAIL:
	mov	dword [_dwMCRNumber], 0
LABEL_MEM_CHK_OK:

	; 初始化全局描述符
	InitDescBase LABEL_SEG_CODE16,LABEL_DESC_CODE16
	InitDescBase LABEL_SEG_CODE32,LABEL_DESC_CODE32
	InitDescBase LABEL_DATA, LABEL_DESC_DATA
	InitDescBase LABEL_STACK, LABEL_DESC_STACK
	; 初始化任务描述符0
	InitTaskDescBase 0
	; 初始化任务描述符1
	InitTaskDescBase 1
	; 初始化任务描述符2
	InitTaskDescBase 2
	; 初始化任务描述符3
	InitTaskDescBase 3
	; 为加载 GDTR 作准备
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址
	; 为加载 IDTR 作准备
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_IDT		; eax <- idt 基地址
	mov	dword [IdtPtr + 2], eax	; [IdtPtr + 2] <- idt 基地址
	; 保存 IDTR
	sidt	[_SavedIDTR]
	; 保存中断屏蔽寄存器(IMREG)值
	in	al, 21h
	mov	[_SavedIMREG], al
	; 加载 GDTR
	lgdt	[GdtPtr]
	; 关中断
	cli
	; 加载 IDTR
	lidt	[IdtPtr]
	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al
	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax
	; 真正进入保护模式
	jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 Code32Selector:0  处
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LABEL_REAL_ENTRY:		; 从保护模式跳回到实模式就到了这里
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, [_wSPValueInRealMode]

	lidt	[_SavedIDTR]	; 恢复 IDTR 的原值

	mov	al, [_SavedIMREG]	; ┓恢复中断屏蔽寄存器(IMREG)的原值
	out	21h, al			; ┛

	in	al, 92h		; ┓
	and	al, 11111101b	; ┣ 关闭 A20 地址线
	out	92h, al		; ┛

	sti			; 开中断

	mov	ax, 4c00h	; ┓
	int	21h		; ┛回到 DOS
; END of [SECTION .s16]



[SECTION .s32]; 32 位代码段. 由实模式跳入.
[BITS	32]
LABEL_SEG_CODE32:
	mov	ax, SelectorData
	mov	ds, ax			; 数据段选择子
	mov	es, ax
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子
	mov	ax, SelectorStack
	mov	ss, ax			; 堆栈段选择子
	mov	esp, TopOfStack

	; 初始化8253A
	call	Init8253A
	call	Init8259A
	; 清屏
	call	ClearScreen
	; 下面显示一个字符串
	push	szPMMessage
	call	DispStr
	add	esp, 4
	push	szMemChkTitle
	call	DispStr
	add	esp, 4
	call	DispMemSize		; 显示内存信息
	; 计算页表个数
	xor	edx, edx
	mov	eax, [dwMemSize]
	mov	ebx, 400000h	; 400000h = 4M = 4096 * 1024, 一个页表对应的内存大小
	div	ebx
	mov	ecx, eax	; 此时 ecx 为页表的个数，也即 PDE 应该的个数
	test	edx, edx
	jz	.no_remainder
	inc	ecx		; 如果余数不为 0 就需增加一个页表
.no_remainder:
	mov	[PageTableNumber], ecx	; 暂存页表个数
	call	LABEL_INIT_PAGE_TABLE0
	call	LABEL_INIT_PAGE_TABLE1
	call	LABEL_INIT_PAGE_TABLE2
	call	LABEL_INIT_PAGE_TABLE3
	; 初始化ticks
	xor 	ecx, ecx 
.initTicks:
	mov     eax, dword [TaskPriority + ecx*4]             
	mov     dword [LeftTicks + ecx*4], eax
	inc   	ecx
	cmp    	ecx, 4
	jne     .initTicks
	xor 	ecx, ecx  
	sti							; 打开中断
	mov		eax, PageDirBase0	; ┳ 加载 CR3
	mov		cr3, eax			; ┛
	mov		ax, SelectorTSS0	; ┳ 加载 TSS
	ltr		ax					; ┛
	mov		eax, cr0			; ┓
	or		eax, 80000000h		; ┣ 打开分页
	mov		cr0, eax			; ┃
	jmp		short .1			; ┛
.1:
	nop
	; 提示初始化完成
.ready:
	xor 	ecx, ecx
	mov		ah, 0Fh
.outputLoop:
	mov		al, [szReadyMessage + ecx]
	mov 	[gs:((80 * 19 + ecx) * 2)], ax
	inc		ecx
	cmp		al, 0
	jnz		.outputLoop
	SwitchTask 0
	call	SetRealmode8259A	; 恢复 8259A 以顺利返回实模式, 未执行
	jmp		SelectorCode16:0	; 返回实模式, 未执行

; int handler ------------------------------------------------------------------
_ClockHandler:
ClockHandler	equ	_ClockHandler - $$
	push	ds
	pushad

	mov		eax, SelectorData
	mov		ds, ax

	mov		al, 0x20
	out		0x20, al

	; 判断LeftTick是否为0, 如果不为0, 则说明当前没有任务在运行, 无需进行任务切换
	mov     edx, dword [RunningTask]               
	mov     ecx, dword [LeftTicks+edx*4]         
	test    ecx, ecx                              
	jnz     .subTicks	; 直接跳转到subTicks, 无需进行任务切换
	; 判断任务是否已经全部执行完毕, 如果全部执行完毕, 重新赋值                              
	mov     eax, dword [LeftTicks]                 
	mov     ebx, edx                                
	or      eax, dword [LeftTicks + 4]                      
	or      eax, dword [LeftTicks + 8]                      
	or      eax, dword [LeftTicks + 12]                      
	jz      .allFinished	; 跳转到allFinished, 重新赋值
.goToNext:  ; 选择下一个任务
	xor     eax, eax                               
	xor     esi, esi
	xor		ecx, ecx                               
.getMaxLoop:  ;	获取Ticks最大的任务
	cmp     dword [LeftTicks+eax*4], ecx           
	jle     .notMax                                   
	mov     ecx, dword [TaskPriority+eax*4]        
	mov     ebx, eax                                
	mov     esi, 1                                  
.notMax:  
	add     eax, 1                                  
	cmp     eax, 4                                  
	jnz     .getMaxLoop    ; 循环获取Ticks最大的任务
	mov     eax, esi                                
	test    al, al                                  
	jz      .subTicks                                   
	mov     dword [RunningTask], ebx    ; RunningTask = ebx      
	mov     edx, ebx
	; switch to task edx
	cmp    	edx, 0
	je     	.switchToTask0
	cmp    	edx, 1
	je     	.switchToTask1
	cmp    	edx, 2
	je     	.switchToTask2
	cmp    	edx, 3
	je     	.switchToTask3
	jmp    	.exit
.switchToTask0:
	SwitchTask 0
.switchToTask1:
	SwitchTask 1
.switchToTask2:
	SwitchTask 2
.switchToTask3:
	SwitchTask 3
.subTicks:  
	sub     dword [LeftTicks+edx*4], 1            
	jmp	 .exit                       

; 若均已结束，重新赋值
.allFinished:  ; Local function
	xor		ecx, ecx
.setLoop:
	mov     eax, dword [TaskPriority + ecx*4]             
	mov     dword [LeftTicks + ecx*4], eax
	inc   	ecx
	cmp    	ecx, 4
	jne     .setLoop
	xor 	ecx, ecx                   
	jmp     .goToNext  
                        
.exit:
	popad
	pop		ds
	iretd

; ---------------------------------------------------------------------------
_UserIntHandler:
UserIntHandler	equ	_UserIntHandler - $$
	mov	ah, 0Ch				; 0000: 黑底    1100: 红字
	mov	al, 'I'
	mov	[gs:((80 * 0 + 70) * 2)], ax	; 屏幕第 0 行, 第 70 列。
	iretd

_SpuriousHandler:
SpuriousHandler	equ	_SpuriousHandler - $$
	mov	ah, 0Ch				; 0000: 黑底    1100: 红字
	mov	al, '!'
	mov	[gs:((80 * 0 + 75) * 2)], ax	; 屏幕第 0 行, 第 75 列。
	iretd
; ---------------------------------------------------------------------------

InitPageTable 0
InitPageTable 1
InitPageTable 2
InitPageTable 3

%include	"lib.inc"	; 库函数
SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]


; 16 位代码段, 由 32 位代码段跳入, 跳出后到实模式.
[SECTION .s16code]
ALIGN	32
[BITS	16]
LABEL_SEG_CODE16:
	; 跳回实模式:
	mov		ax, SelectorNormal
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
	mov		ss, ax

	mov		eax, cr0
	; and		al, 11111110b	; 仅切换到实模式
	and		eax, 7ffffffeh		; 切换到实模式并关闭分页
	mov		cr0, eax

LABEL_GO_BACK_TO_REAL:
	jmp		0:LABEL_REAL_ENTRY	; 段地址会在程序开始处被设置成正确的值

Code16Len	equ	$ - LABEL_SEG_CODE16
; END of [SECTION .s16code]