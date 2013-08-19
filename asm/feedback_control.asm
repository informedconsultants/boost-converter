;; feedback control
org 0	
ljmp main
org 000Bh
	push 	dph
	push	dpl
	push 	acc
	mov 	TH0, #0feh
	mov	TL0, #03dh
	dec 	08h
	lcall 	t_isr
	pop 	acc
	pop	dpl
	pop	dph
	reti

main:
	lcall	init
	mloop:
		lcall	update_lcd
		sjmp 	mloop

update_lcd:
	lcall clrdisp
	lcall get_dac
	lcall proc_dac
	lcall print_lcd
	ret
init:
	;; control register is located at #FE07
	mov	dptr, #0fe07h
	mov 	a, #80h
	movx 	@dptr, a
	mov 	dpl, #06h
	mov 	a, #00h
	movx 	@dptr, a
	mov 	dpl, #05h
	mov 	a, #038h
	movx 	@dptr, a
	lcall 	enbpulse
	lcall 	dispon
	mov 	dpl, #05h
	mov 	a, #80h
	movx 	@dptr, a
	lcall 	enbpulse
	lcall 	clrdisp
	mov	dptr, #0fe03h
	mov	a, #0b4h
	movx	@dptr, a
	mov	dptr, #0fe03h
	mov	a, #072h
	movx	@dptr, a
	mov	dptr, #0fe02h
	mov	a, #0ffh
	movx	@dptr, a
	mov	dptr, #0fe02h
	mov	a, #00h
	movx	@dptr, a
	mov	08h, #0ffh
	mov	r2, #00fh
	mov	r3, #0a0h
	mov	r5, #80h
	mov	dptr, #1000h
	movx	a, @dptr
	mov	r6, a
	lcall	timer_init
	ret
	
timer_init:
	mov	r3, #0fah
	mov	r5, #80h
	mov	dptr, #1000h
	movx	a, @dptr
	mov	r6, a
	;; timer 0 - mode 1
	mov 	TMOD, #01h
	setb 	TR0
	mov 	TH0, #0feh
	mov	TL0, #033d
	setb 	EA	
	setb 	ET0
	ret

t_isr:
	lcall	update_counter
	lcall	get_dac
	lcall 	command_comp
	lcall	pwm
	ret

update_counter:
	mov	a, r2
	orl	a, r3
	jz	res_switch
	djnz	r3, updone
	dec 	r2
	ret

res_switch:
	mov 	r2, #00fh
	;; reset counter to 400d
	mov	r3, #0a0h
	mov	a, r5
	;; switch to 128 or 0
	cpl	acc.7
	mov	r5, a
	ret

updone:
	ret

pwm:
	mov	dptr, #0fe01h
	movx	@dptr, a
	mov	dptr, #0fe01h
	mov	a, #00h
	movx	@dptr, a
	ret
	
command_comp:	
	mov	a, r5
	clr	c
	subb	a, r4
	jc	lowval
	mov	b, r6
	mul	ab
	mov	r7, b
	cjne	r7, #00h, highval
	ret

	;; negative error
lowval:	
	mov	a, #00h
	ret

	;; command>256
highval:			
	mov	a, #0ffh
	ret

	;; dac reading
get_dac: 
	mov	dptr, #0fe00h
	movx	@dptr, a

	waitrcv:
		jnb P3.3, waitrcv
	
	movx	a, @dptr
	mov	r4, a
	ret

	;; process the dac reading which should be in acc
proc_dac:
	mov 	b, #50h
	mul	ab
	;; divide value in acc by 256
	anl	a, #80h
	rl	a
	mov	p1, a
	add	a, b
	mov	b, #10
	div	ab
	push	acc
	mov	a, #30h
	add 	a, b
	mov	b, a
	pop 	acc
	
	push 	b
	mov	b, #30h
	add	a, b
	pop	b
	ret

print_lcd:
	;; push return address to dptr
	push	dph
	push	dpl
	push	b
	
	lcall	wrchar
	mov	a, #0A5h
	lcall	wrchar
	
	pop	b
	mov	a, b
	lcall	wrchar
	
	mov	a, r6
	lcall	wrchar
	pop	dpl
	pop	dph
	ret


clrdisp:
	mov	dpl, #05h
	mov	a, #01h
	movx	@dptr, a
	lcall	enbpulse
	ret

enbpulse:
	;; pulse enable low -- write 0b00011111 to Port C
	mov	dpl, #06h
	mov	a, #80h
	movx	@dptr, a
	lcall	enbwait
	mov	dpl, #06h
	mov	a, #00h
	movx	@dptr, a
	ret
	
	;; send a low pulse to the enable bit while not in command mode
wrenbpulse:
	mov	dpl, #06h
	mov	a, #0BFh
	movx	@dptr, a
	lcall	enbwait
	lcall	enbwait
	mov	dpl, #06h
	mov	a, #03Fh
	movx	@dptr, a
	ret

enbwait:
	wmain:
		mov	r1, #003h
	wloopa:
		mov	r0, #0ffh
	wloopb:
		djnz	r0, wloopb
		djnz	r1, wloopa
	ret
	
wrchar:
	mov	P1, a
	mov	r2, a
	mov	dpl, #06h
	mov	a, #0BFh
	movx	@dptr, a
	mov	dptr, #0fe05h
	mov	a, r2
	movx	@dptr, a
	lcall	wrenbpulse
	ret
	
	
dispon:
	mov	dpl, #05h
	mov	a, #0Eh
	movx	@dptr, a
	lcall	enbpulse
	ret