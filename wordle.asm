IDEAL
JUMPS
MODEL small
STACK 100h

BMP_WIDTH = 320
BMP_HEIGHT = 200

WinMenu_Width = 200
WinMenu_Height = 58

FILE_NAME_IN  equ './projfile/MainMenu.bmp'
File_Name_In_HowToPlay equ './projfile/HTP.bmp'

MaxLettersInWord = 10

; In the Leaderboard:
MAX_PLAYERS = 5
PLAYER_SIZE = 11

DATASEG
	
	RndCurrentPos dw start
	
	UserName db 10 dup(0), '$'
	
	RandomWord db MaxLettersInWord dup (" "), '$'
;	 ^^^
	TmpWord db MaxLettersInWord dup (" ") 
	currentLine db MaxLettersInWord dup(0)
	TmpCurrentLine db MaxLettersInWord dup (0)
	
	File_Name_HowToPlay db File_Name_In_HowToPlay, 0
	
	FiveLettersFile db "./projfile/fiveL.txt", 0
	FourLettersFile db "./projfile/fourL.txt", 0
	SixLettersFile db "./projfile/sixL.txt", 0
	SevenLettersFile db "./projfile/sevenL.txt", 0
	
	YouWinFile db './projfile/YouWin.bmp', 0
	YouLostFile db './projfile/YouLost.bmp', 0
	
	LeaderBoardFile db "./projfile/Lboard.txt", 0
	LeaderBoardFileHandle dw ?
	lbBuffer db ?
	ScoreBuffer db "  " ; Score can only be 2 digits or 1
	ESCText db "Press ESC to return to main menu", '$'
	
	PaletteBackup db 400h dup (0)
	
	; ############## Start BMP ##############
	OneBmpLine 	db BMP_WIDTH dup (0)
   
    ScrLine 	db BMP_WIDTH+4 dup (0)

	FileName 	db FILE_NAME_IN ,0
	FileHandle	dw ?
	Header 	    db 54 dup(0)
	Palette 	db 400h dup (0)
	
	BmpFileErrorMsg    	db 'Error At Opening Bmp File ',FILE_NAME_IN, 0dh, 0ah,'$'
	ErrorFile           db 0

	BmpLeft dw ?
	BmpTop dw ?
	BmpColSize dw ?
	BmpRowSize dw ? 
	; ############## End BMP ##############
	
	shouldExit db 0
	ModeChosen db ? ; can be 4, 5, 6, 7
	
	
	WordFromFile db MaxLettersInWord + 2 dup (0)
	
	
	CurrentLineY dw 2
	startX dw 13
	startY dw 2
	
	CurrentFileHandle dw 0
	
	WinsCtr db 0 ; The score
	
	NameText db "Enter your name:", '$'
	
	LBLine db 23 dup (?) ; 19 for line and 4 for 2 \n
	Leaderboard db MAX_PLAYERS * PLAYER_SIZE dup(0)
	CurrentPlayer db PLAYER_SIZE dup(0)
	OrdinalLookup db "1st2nd3rd4th5th"
	LeaderboardFileHeader db "RANK: NAME:      SCORE:", 0Dh, 0Ah, 0Dh, 0Ah

CODESEG
start:
	mov ax, @data
	mov ds, ax
	
	; Get the name of the user before strating the game
	call EnterYourName
	call StartGame
	
exit:

	mov ax, 2
	int 10h
	
	mov ax, 4c00h
	int 21h

;#####################################
;
; Takes care of the whole game loop
;
;#####################################
proc StartGame
	
	call SetGraphic
	mov al, 0
	call ClearScreen
	
	call SavePalette

	call ShowMainScreen
	
	call LoadPalette
	
	mov ax, 0
	call ClearScreen
	
	
	
	; Generate random word by the mode chosen
	call SetCurrentFileHandle
	push [CurrentFileHandle]
	call GetRandomWord
	call DrawGameBoard
	
MainLoop: 
	
	; Check if pressed Esc to end the game
	call GetKeyPressed
	call HandleInput
	cmp [shouldExit], 0
	je skipExit
	
	call RestartVars
	
	call StartGame
	jmp exit
	
skipExit:

	jmp MainLoop

	ret
endp StartGame

;#####################################
;
; Takes care of the whole next round
; very similar to start game
;
;#####################################
proc NextRound
	
	call LoadPalette
	call RestartVars
	mov ax, 0
	call ClearScreen
	
	call SetCurrentFileHandle
	push [CurrentFileHandle]
	call GetRandomWord
	
	call DrawGameBoard
	
@@MainLoop: 
	
	; Check if pressed Esc to end the game
	call GetKeyPressed
	call HandleInput
	cmp [shouldExit], 0
	je @@skipExit
	
	call RestartVars
	call StartGame
	jmp exit
	
@@skipExit:

	jmp @@MainLoop

	ret
endp NextRound

;#####################################
;
; Sets the current file handle by the
; game mode chosen by the player
;
;#####################################
proc SetCurrentFileHandle
	
	; Close the file used before
	; cause error 04 if Not
	; (too many handles)
	cmp [CurrentFileHandle], 0
	je @@SkipClose
	push [CurrentFileHandle]
	call CloseFile
	@@SkipClose:
	
	cmp [ModeChosen], 4
	jne @@Not_Four
	
	mov [startX], 15
	
	push 0
	push offset FourLettersFile
	call OpenFile
	mov [CurrentFileHandle], ax
	jmp @@ret
	
	@@Not_Four:
	
	cmp [ModeChosen], 5
	jne @@Not_Five
	
	mov [startX], 13
	
	push 0
	push offset FiveLettersFile
	call OpenFile
	mov [CurrentFileHandle], ax
	jmp @@ret
	
	@@Not_Five:
	
	cmp [ModeChosen], 6
	jne @@Not_Six
	
	mov [startX], 12
	
	push 0
	push offset SixLettersFile
	call OpenFile
	mov [CurrentFileHandle], ax
	jmp @@ret
	
	@@Not_Six:
	
	cmp [ModeChosen], 7
	jne @@Not_Seven
	
	mov [startX], 10
	
	push 0
	push offset SevenLettersFile
	call OpenFile
	mov [CurrentFileHandle], ax
	jmp @@ret
	
	@@Not_Seven:
	@@ret:
	ret
endp SetCurrentFileHandle

;#####################################
;
; Won't start the game until the user
; puts his name cause we need the name
; for the leaderboard
;
; Puts the name the player wrote In
; "UserName"
;
; boardX - the position of the letter
; box
;
;#####################################
boardX = [word bp - 2]
proc EnterYourName
	
	push bp
	mov bp, sp
	
	sub sp, 2
	
	call SetGraphic
	
	mov ax, 0
	call ClearScreen
	
	mov ah, 2
	mov bh, 0
	mov dh, 5
	mov dl, 12
	int 10h
	
	mov dx, offset NameText
	mov ah, 9
	int 21h
	
	mov ax, 6
	mov boardX, ax
	
		mov cl, 10
		@@colLoop:
			
			push 27
			push ' '
			push boardX
			push 8
			push 18
			push 18
			push 1
			call DrawRectWithLetter
			
			add boardX, 3
			loop @@colLoop
		
	mov bx, 6 ; The place of the current box
	mov di, offset UserName
	xor ax, ax
	@@LoopName:
	
		call GetKeyPressed
		cmp ax, 0E08h ; BackSpace
		jne @@DontDelete
			
			sub bx, 3
			
			cmp bx, 6 ; If at the start
			jb @@DontDelete
			
			push bx
			call DeleteLetterForName
			
			mov [byte di], 0
			dec di
			
		@@DontDelete:
		cmp bx, 6 ; If deleted the first letter
		jnb @@DontAdd
			
			mov bx, 6
			
		@@DontAdd:
		
		cmp ax, 1C0Dh ; Enter
		jne @@DidntEnter
		
			cmp bx, 12 ; If the name is less than 2 letters
			jb @@DidntEnter
			
			jmp @@EntererName
		
		@@DidntEnter:
		
		cmp bx, 33
		ja @@NotLetter
		
		push ax
		push ax
		call IsEngLetter
		cmp ax, 1
		pop ax
		jne @@NotLetter
		
			push 27
			push ax
			push bx
			push 8
			push 18
			push 18
			push 1
			call DrawRectWithLetter
			add bx, 3
			
			mov [di], al ; Puts in user name
			inc di
		
		@@NotLetter:
		
	jmp @@LoopName
	
	@@EntererName:
	
	mov sp, bp
	pop bp
	ret 2
endp EnterYourName

;#####################################
;
; deletes the letter box that has been pushed
; boardX - What letter box to delete
;
;#####################################
boardX = [bp + 4]
proc DeleteLetterForName
	
	push bp
	mov bp, sp

		push 27
		push ' '
		push boardX
		push 8
		push 18
		push 18
		push 1
		call DrawRectWithLetter
	
	pop bp
	ret 2
endp DeleteLetterForName
	
;#####################################
;
; Gets the key that the user pressed
; returns in ax the scan code
;
;#####################################
proc GetKeyPressed

	mov ah, 0
	int 16h
	; in ax the scan code

	ret
endp GetKeyPressed

;#####################################
;
; Resets all the veriables that are used
; in each round/game
;
;#####################################
proc RestartVars

	mov [shouldExit], 0
	mov [CurrentLineY], 2
	mov bx, offset currentLine
	mov cx, MaxLettersInWord
	
	; Resets current line
	@@loop:
		mov [byte bx], 0
		inc bx
		loop @@loop
		
	mov bx, offset RandomWord
	mov cx, MaxLettersInWord
	
	; Resets the word to guess
	@@loop1:
		mov [byte bx], 0
		inc bx
		loop @@loop1
	

	ret
endp RestartVars
;#####################################
;
; Handles what happens next in the game
; put the key pressed in ax before calling
;
;#####################################

key = [word bp - 2]
proc HandleInput
	
	push bp
	mov bp, sp
	
	sub sp, 2
	
	mov key, ax
	
	mov [shouldExit], 0
	
	cmp key, 011Bh ; Esc
	jne @@NotEsc
	mov [shouldExit], 1
	call UpdateLeaderboard ; When pressed ESC
	jmp @@ret
	@@NotEsc:
	
	cmp key, 1C0Dh ; Enter
	jne @@NotEnter
	
	; first change
	call IsValidWord
	
	cmp ax, 1
	jne @@ret ; Not valid
	
	push [startX]
	call ChangeColors
	cmp di, 1
	jne @@NotWin
	
	; second change
	;mov ah, 1
	;int 21h
	
	call Win
	@@NotWin:
	add [CurrentLineY], 3
	
	xor ax, ax
	mov al, 6
	mov bl, 3
	mul bl
	cmp [CurrentLineY], ax
	jna @@NotLost
	call Lost
	
	@@NotLost:
	call ResetCurrentLine
	jmp @@ret
	
	@@NotEnter:
	cmp key, 0E08h ; BackSpace
	jne @@NotBackSpace
	call DeleteLetter
	jmp @@ret
	@@NotBackSpace:
	push key
	call IsEngLetter ; Puts in ax 0 or 1 if the key is an Eng letter
	cmp ax, 0
	je @@ret
	
	mov ax, key
	push ax
	call AddLetterToCurrentLine
	call PrintCurrentLine
	
@@ret:
	
	mov sp, bp
	pop bp
	ret 2
endp HandleInput

;#####################################
;
; Handles the situation when the user won
;
;#####################################
proc Win
	
	inc [WinsCtr]
	
	call SavePalette
	
	call SetGraphic
	mov dx, offset YouWinFile
	mov [BmpLeft],60
	mov [BmpTop],71
	mov [BmpColSize], WinMenu_Width
	mov [BmpRowSize] ,WinMenu_Height
	
	call OpenShowBmp
	cmp [ErrorFile],1
	jne @@cont 
	jmp @@exitError
@@cont:

	
    jmp @@return
	
@@exitError:
	mov ax,2
	int 10h
	
    mov dx, offset BmpFileErrorMsg
	mov ah,9
	int 21h
	
@@return:
	
	; wait for left click action
	mov ax, 1
	int 33h
	xor bx, bx
@@waitForLeftClick:

	mov ax, 3
	int 33h
	
	cmp bx, 1
	jne @@waitForLeftClick
	
	; Did click the main menu button
	push 169
	push 100
	push 250
	push 124
	call IsIn
	cmp ax, 0
	je @@NotMenu
	
	call UpdateLeaderboard
	mov [WinsCtr], 0
	call RestartVars
	call StartGame
	
	@@NotMenu:
	; Did click the next round button
	push 70
	push 100
	push 152
	push 124
	call IsIn ; 
	cmp ax, 0
	je @@waitForLeftClick
	mov ax, 2
	int 33h
	call NextRound
	
	call LoadPalette

	ret
endp Win

;#####################################
;
; Handles the situation when the user lost
;
;#####################################
proc Lost

	call SavePalette
	
	call SetGraphic
	mov dx, offset YouLostFile
	mov [BmpLeft],60
	mov [BmpTop],71
	mov [BmpColSize], WinMenu_Width
	mov [BmpRowSize] ,WinMenu_Height
	
	call OpenShowBmp
	cmp [ErrorFile],1
	jne @@cont 
	jmp @@exitError
@@cont:

	
    jmp @@return
	
@@exitError:
	mov ax,2
	int 10h
	
    mov dx, offset BmpFileErrorMsg
	mov ah,9
	int 21h
	
@@return:
	
	; puts the right word in screen: 15, 45 start of word
	
	mov ah, 2
	mov bh, 0
	mov dh, 117
	mov dl, 57
	int 10h
	
	mov dx, offset RandomWord
	mov ah, 9
	int 21h
	
	mov si, 37830
	
	mov cx, 10
	@@firstloop:
		push si
		push cx

		mov cx, 85
		@@secondloop:
			cmp [byte es:si], 0
			jne @@skipdraw
			mov al, 255 ; White (in the current palette)
			mov [byte es:si], al
			@@skipdraw:
			inc si
			loop @@secondloop
	
		pop cx
		pop si
		add si, 320
		loop @@firstloop
	
	; wait for left click action
	mov ax, 1
	int 33h
	xor bx, bx
@@waitForLeftClick:

	mov ax, 3
	int 33h
	
	cmp bx, 1
	jne @@waitForLeftClick
	
	; Did click the main menu button
	push 169
	push 100
	push 250
	push 124
	call IsIn
	cmp ax, 0
	je @@waitForLeftClick
	
	call UpdateLeaderboard
	mov [WinsCtr], 0
	call RestartVars
	call StartGame
	call LoadPalette
	ret
endp Lost

;################################
;
;	Opens leader board file,
;	print the leader board and return
;	to main menu afetr user pressed ESC
;	Closes leader board file
;
;################################
proc UpdateLeaderboard
	
	push 2
	push offset LeaderBoardFile
	call openFile
	mov [LeaderBoardFileHandle], ax
	call LoadLeaderboard
	call CreatePlayerObject
	call InsertToLeaderboard
	call ExportLeaderboard
	
	push [LeaderBoardFileHandle]
	call CloseFile
	
	ret
endp UpdateLeaderboard

;################################
;
;	Opens leader board file,
;	print the leader board and return
;	to main menu afetr user pressed ESC
;	Closes leader board file
;
;################################
proc ShowLeaderboard
	
	mov ax, 2
	int 33h
	
	mov ax, 0
	call ClearScreen
	
	; Opens the leader board file
	push 0
	push offset LeaderBoardFile
	call OpenFile
	mov [LeaderBoardFileHandle], ax
	
	mov al, 2
	mov bx, [LeaderBoardFileHandle]
	xor cx, cx
	xor dx, dx
	mov ah, 42h
	int 21h
	mov di, ax ; The Length of the file
	
	; Returns to the beginning 
	mov ah, 42h
	mov al, 0
	mov bx, [LeaderBoardFileHandle]
	xor cx, cx
	xor dx, dx
	int 21h

	mov cx, di
	@@PrintFileLoop:
		push cx
		
		; Reads a byte from the file
		mov dx, offset lbBuffer
		mov bx, [LeaderBoardFileHandle]
		mov cx, 1
		mov ah, 3fh
		int 21h
		
		; Prints the current byte
		mov ah, 0Eh
		mov al, [lbBuffer]
		mov bh, 0
		mov bl, 255 ; White
		int 10h
		
		pop cx
	loop @@PrintFileLoop
	
	; Last row
	mov ah, 2
	mov bh, 0
	xor dl, dl
	mov dh, 24
	int 10h
	
	mov si, offset ESCText
	mov cx, 32
	@@LoopPrintESC:
	
		mov ah, 0Eh
		mov al, [si]
		mov bh, 0
		mov bl, 255 ; White
		int 10h
		
		inc si
		loop @@LoopPrintESC
		
	@@WaitTillESC:
	
		call GetKeyPressed
	
	cmp ax, 011Bh ; Esc
	jne @@WaitTillESC
	
	push [LeaderBoardFileHandle]
	call CloseFile
	
	mov ax, 1
	int 33h

	ret
endp ShowLeaderboard

;#####################################
;
; Converts all the data that is in the
; leaderboard into a A Player[] array
; called Leaderboard
;
;#####################################
proc LoadLeaderboard 
	
	; Skip the first row of lb - RANK, NAME, SCORE
	push 1Bh
	push [LeaderBoardFileHandle]
	call SkipBytes
	
	mov di, offset Leaderboard
	mov cx, MAX_PLAYERS
	@@LoopRow:

		; Reads the current line into LBLine
		push offset LBLine
		push 23 
		push [LeaderBoardFileHandle]
		call ReadFile
		
		mov bx, offset LBLine
		add bx, 6
		
		; Copy name until space - ' '
		@@LoopCopyName:
			cmp [byte bx], ' '
			je @@ReachedSpace
				mov al, [bx]
				mov [di], al
				inc bx
				inc di
			jmp @@LoopCopyName
		@@ReachedSpace:
		
		; bx - Skip all spaces after the name
		; di - כדי שיהיה מקום קבוע לשם ולניקוד
		; the number of chars between the start of name and score is 11, 
		; we advance bx to skip all the spaces until the score and advance di
		; 10 - name.Length times so the name section in the lb is always 10
		; (we dec di at the end so its 10 and not 11)
		@@LoopSkipSpaces:	
			cmp [byte bx], ' '
			jne @@ReachedNextLetter
			inc bx
			inc di
			jmp @@LoopSkipSpaces
		@@ReachedNextLetter:
		dec di
		
		; --- Put the score in di ---
		; Converts the left char of the score
		mov al, [bx]
		sub al, 30h
		
		; Converts the right char of the score
		mov ah, [bx + 1]
		cmp ah, ' '
		je @@ScoreIsDigit
		sub ah, 30h
		
		; Left * 10 + right
		mov dl, ah
		xor ah, ah
		mov dh,10
		mul dh
		add al, dl
		
		@@ScoreIsDigit:
		
			mov [di], al
			inc di
			
		@@SkipScoreIsDigit:
		loop @@LoopRow
	
	ret
endp LoadLeaderboard

;#####################################
;
; Makes a new Leaderboard file with the
; updated data
;
;#####################################
proc ExportLeaderboard
	
	mov ah, 41h
	mov dx, offset LeaderBoardFile
	int 21h
	
	mov ah, 3Ch
	mov cx, 64
	mov dx, offset LeaderBoardFile
	int 21h
	mov [LeaderBoardFileHandle], ax
	
	mov bx, offset LBLine
	mov cx, 23
	@@loopResetLBLline:
		
		mov [byte bx], ' '
		inc bx
		
		loop @@loopResetLBLline
	
	mov ah, 42h
	mov al, 0
	mov bx, [LeaderBoardFileHandle]
	xor cx, cx
	xor dx, dx
	int 21h
	
	mov ah, 40h
	mov bx, [LeaderBoardFileHandle]
	mov cx, 27
	mov dx, offset LeaderboardFileHeader
	int 21h
	
	xor dx, dx
	mov di, offset Leaderboard
	
	mov cx, MAX_PLAYERS
	@@PlayerLoop:
		
		;########################################################
		; #Start# - Puts all the places in LBLine (1st2nd3rd4th5th)
		; With the correct format:
		; '1st   '
		; '2nd   '
		; '3rd   '
		; '4th   '
		; '5th   '
		;########################################################
		
		mov bx, offset LBLine
		mov si, offset OrdinalLookup
		
		mov ax, dx ; index
		push bx
		mov bl, 3
		mul bl
		pop bx
		
		add si, ax
		
		mov al, [si]
		mov [bx], al
		inc bx
		inc si
		
		mov al, [si]
		mov [bx], al
		inc bx
		inc si
		
		mov al, [si]
		mov [bx], al
		inc bx
		
		mov [byte bx], ' '
		inc bx
		mov [byte bx], ' '
		inc bx
		mov [byte bx], ' '
		inc bx
		; #End#
		
		; Puts the name in LBLine in the correct format (10 letters)
		push cx
		mov cx, 10
		@@NameLoop:
			
			cmp [byte di], 0
			je @@Space
				
				; the name
				mov al, [di]
				mov [bx], al
				jmp @@ContLoop
				
			@@Space:
				mov [byte bx], ' '
			
			@@ContLoop:
			
			inc bx
			inc di
			
			loop @@NameLoop
		
		; A space between the name and the score
		mov [byte bx], ' '
		inc bx
		
		; Converts the score into char
		xor ah, ah
		mov al, [di]
		
		push dx
		mov dl, 10
		div dl
		pop dx
		
		cmp al, 0
		jne @@Double
		
			add ah, 30h
			mov [bx], ah
			inc bx
			mov [byte bx], ' '
			jmp @@SkipDouble
			
		@@Double:
			
			add al, 30h
			mov [bx], al
			inc bx
			add ah, 30h
			mov [bx], ah
			
		@@SkipDouble:
		inc di
		
		; Go down a line
		cmp cx, 1
		je @@SkipLineBreak
		inc bx
		mov [byte bx], 0Dh
		inc bx
		mov [byte bx], 0Ah
		inc bx
		mov [byte bx], 0Dh
		inc bx
		mov [byte bx], 0Ah
		@@SkipLineBreak:
		
		
		push bx
		push dx
		
		; Prints the LBLline into the leaderboaedfile
		mov ah, 40h
		mov bx, [LeaderBoardFileHandle]
		mov cx, 23
		mov dx, offset LBLine
		int 21h
		
		pop dx
		pop bx
		
		inc dx
		pop cx
		loop @@PlayerLoop
	
	ret
endp ExportLeaderboard

;#####################################
;
; Transfers the data of the name and
; score of the player into the format
; of the player object
;
;#####################################
proc CreatePlayerObject

	mov di, offset CurrentPlayer
	mov bx, offset UserName
	mov cx, 10
	@@LoopPutChar:
		
		mov al, [bx]
		mov [di], al
		inc bx
		inc di
		
		loop @@LoopPutChar
	
	mov al, [WinsCtr]
	mov [di], al
	
	ret
endp CreatePlayerObject

;#####################################
;
; Puts the current player into the
; array and sorts it with Insertsort
;(Makes sure that the array stays with
; 5 players)
;
;#####################################
proc InsertToLeaderboard
	
	xor ax, ax
	
	mov bx, offset CurrentPlayer
	add bx, 10
	mov al, [bx] ; Score
	
	mov di, offset Leaderboard
	add di, MAX_PLAYERS * PLAYER_SIZE - 1 ; score of last player
	
	mov cx, MAX_PLAYERS
	@@LoopPlaces:
	
		cmp [di], al
		jae @@NotInLB
		
		cmp cx, MAX_PLAYERS
		je @@DontMoveDown
		
		push cx
		mov bx, offset Leaderboard
		
		push ax
		
		mov al, cl
		dec al
		mov dl, PLAYER_SIZE
		mul dl
		add bx, ax ; the index of the place we are putting the player in
		
		pop ax
		
		push bx
		call CopyPlayer
		
		@@DontMoveDown:
		
		mov bx, cx
		dec bx
		push bx
		push offset CurrentPlayer
		call CopyPlayer
		
		; Moves to the score of the player before
		sub di, 11
		
		loop @@LoopPlaces
	
	@@NotInLB:
	
	ret
endp InsertToLeaderboard


;###################################################
;
; copies a player to a place in the Leaderboard
; index - a position in the leaderboard
; PlayerOffset - the player
;
;###################################################
Index = [byte bp + 6]
PlayerOffset = [word bp + 4]
proc CopyPlayer
	
	push bp
	mov bp, sp
	push cx
	push ax
	push bx
	push di
	
	xor ax, ax
	
	mov al, Index
	mov bl, PLAYER_SIZE
	mul bl
	
	mov bx, PlayerOffset
	mov di, offset Leaderboard
	add di, ax
	
	mov cx, 11
	@@LoopPutPlayer:
	
		mov al, [bx]
		mov [di], al
		inc bx
		inc di
	
		loop @@LoopPutPlayer
	
	pop di
	pop bx
	pop ax
	pop cx
	pop bp
	ret 4
endp CopyPlayer

;################################################
;
; Skips a curtine amount of bytes in a file
; BytesToSkip - the amount of bytes to skip
; HandleToUse - the file that we are skipping in
;
;################################################
BytesToSkip = [bp + 6]
HandleToUse = [bp + 4]
proc SkipBytes

	push bp
	mov bp, sp
	
		mov ah, 42h
		mov al, 1
		mov bx, HandleToUse
		xor cx, cx
		mov dx, BytesToSkip
		int 21h
	
	pop bp
	ret 4
endp SkipBytes

;#####################################
;
; resets the current line
;
;#####################################
proc ResetCurrentLine

	mov bx, offset currentLine
	mov cx, MaxLettersInWord
	
	@@loop:
		mov [byte bx], 0
		inc bx
		loop @@loop

	ret
endp ResetCurrentLine
;#####################################
;
; Check if the pressed key is a lowercase
; letter in English
; returns in ax 1 or 0
;
;#####################################
key = [word bp + 4]
proc IsEngLetter

	push bp
	mov bp, sp
	push bx
	
	
	mov ax, 0
	
	mov bx, key
	cmp bl, 'z'
	ja @@NotEng
	
	cmp bl, 'A'
	jb @@NotEng
	
	cmp bl, 'Z'
	ja @@SecondCheck
	@@SecondCheck:
	
		cmp bl, 'a'
		jb @@NotEng
	
	@@Eng:
		
		mov ax, 1
		jmp @@NotEng
	
	
	
	@@NotEng:
	
	pop bx
	pop bp
	ret 2
endp IsEngLetter

;#####################################
;
; Deletes a letter from current line
; and from the gameboard
;
;#####################################
proc DeleteLetter
	
	mov bx, offset currentLine
	cmp [byte bx], 0
	je @@ret
	inc bx
	
	mov dx, [startX]
	
	xor cx, cx
	mov cl, [ModeChosen]
	@@loopTillZero:
		cmp [byte bx], 0
		jne @@NotZero
		
		dec bx
		mov [byte bx], 0
		jmp @@DrawEmpty
		
		@@NotZero:
				
			inc bx
			add dx, 3
			
		loop @@loopTillZero
		
	@@DrawEmpty:
		
		push 27
		push ' '
		push dx
		push [CurrentLineY]
		push 18
		push 18
		push 1
		call DrawRectWithLetter
		
	@@ret:
		
	ret
endp DeleteLetter

;#####################################
;
; Check if the word entered is avvalid word
; must be in the word database and in
; the correct length
; returns in ax 1 or 0 
;
;#####################################

proc IsValidWord
	
	; Check if currentLine is within the letter range 
	xor ax, ax ; counter
	mov bx, offset currentLine
	mov cx, MaxLettersInWord
	@@loopTillZero:
		
		cmp [byte bx], 0
		jne @@cont
		
		cmp al, [ModeChosen]
		xor ax, ax
		jb @@ret
		jmp @@WithinLetterRange
		
		@@cont:
		
			inc ax
			inc bx
			loop @@loopTillZero
			
			
			
	@@WithinLetterRange:
	
		; Is in Words File
		push [CurrentFileHandle]
		call GetWordCount
		push ax
		
		mov ah, 42h
		mov al, 0
		mov bx, [CurrentFileHandle]
		xor cx, cx
		xor dx, dx
		int 21h
		
		pop ax
		mov cx, ax
		xor ax, ax
		@@loopCheckWords:
		
			
			
			push offset WordFromFile
			mov al, [ModeChosen]
			inc al
			inc al
			push ax
			push [CurrentFileHandle]
			call ReadFile

			
			mov bx, offset WordFromFile
			mov si, offset currentLine
			
			push cx
			xor cx, cx
			mov cl, [ModeChosen]
			@@loopAreTheSame:
				
				mov al, [bx]
				cmp al, [si]
				jne @@NotTheSame
				
				inc bx
				inc si
				
				loop @@loopAreTheSame
				
				; In the file - valid word!
				pop cx
				mov ax, 1
				jmp @@ret
				
			@@NotTheSame:
				pop cx
				
			loop @@loopCheckWords
			
			mov ax, 0 ; Not Valid
	
	@@ret:
	
	ret
endp IsValidWord

;######################################################
;
; Changes the colors of the letters
; in the gameboard accordint to its position
; returns in di 1 if won 0 if not
; _startX - the place where the first letter is In
; GreenLetterCnt - the counter of how many correct letters there are in the user's word
; ind2 - The index of the letters in the correct word
; ind1 - The index of the letters in the user word
;
;######################################################

_startX = [word bp + 4]
GreenLetterCnt = [byte bp - 8]
foundClr = [byte bp - 6] ; bool
ind2 = [byte bp - 4]
ind1 = [byte bp - 2]
proc ChangeColors

	push bp
	mov bp, sp
	sub sp, 8
	
	mov GreenLetterCnt, 0
	mov ind2, 0
	mov ind1, 0
	
	; copy random word to tmp word
	
	mov bx, offset RandomWord
	mov di, offset TmpWord
	
	xor ax, ax
	xor cx, cx
	mov cl, [ModeChosen]
	@@loopTmp:
		
		mov al, [bx]
		mov [di], al
		
		inc bx
		inc di
		
		loop @@loopTmp
	; have tmp word
	
	
	; copy current line to tmp line
	mov bx, offset currentLine
	mov di, offset TmpCurrentLine
	
	xor ax, ax
	xor cx, cx
	mov cl, [ModeChosen]
	@@loopUserTmp:
		
		mov al, [bx]
		mov [di], al
		
		inc bx
		inc di
		
		loop @@loopUserTmp
	
	
	
	; clear the first row so i cant draw color letters
	push _startX
	push [CurrentLineY]
	push 180
	push 18
	call ClearRow
	
	
	
	; Check for greens
	
	mov bx, offset TmpWord
	mov di, offset TmpCurrentLine
	
	xor cx, cx
	mov cl, [ModeChosen]
	@@CheckForGreen:
		
		mov al, [di]
		cmp [byte bx], al
		jne @@NotGreen
		
		mov dx, [di]
		mov [byte bx], 0
		mov [byte di], 0
		xor ax, ax
		
		push dx ; letter
		
		mov al, ind1
		mov dl, 3
		mul dl
		add ax, _startX
		push ax
		call DrawGreenRect
		inc GreenLetterCnt
		
		@@NotGreen:
		
		inc bx
		inc di
		inc ind1
			
		loop @@CheckForGreen
	
	mov cl, GreenLetterCnt
	cmp cl, [ModeChosen]
	jne @@DidintWin
	mov di, 1
	jmp @@ret
	@@DidintWin:
	
	mov ind1, 0
	mov di, offset TmpCurrentLine
	xor cx, cx
	mov cl, [ModeChosen]
	@@UserWordLoop:
		
		mov foundClr, 0
		mov ind2, 0
		mov bx, offset TmpWord
		
		push cx
		cmp [byte di], 0
		je @@ContUserLoop
		
		xor cx, cx
		mov cl, [ModeChosen]
		@@TempWordLoop:
			
			mov foundClr, 0
			
			cmp [byte bx], 0
			jne @@ValidLetter
				mov foundClr, 1
			@@ValidLetter:
			
			mov al, [byte di]
			cmp [bx], al ; check if the letters are the same
			jne @@NotYellow
			
			mov al, ind2
			cmp ind1, al ; check if the position of the letters is the same
			je @@NotYellow
			
			cmp foundClr, 1
			je @@NotYellow
				
				xor ax, ax
				
				mov dx, [di]
				push dx ; letter
				mov al, ind1
				mov dl, 3
				mul dl
				add ax, _startX
				push ax
				
				call DrawYellowRect
				
				mov [byte bx], 0
				mov [byte di], 0
				jmp @@ContUserLoop
			
			@@NotYellow:
			
			inc bx
			inc ind2
			
			loop @@TempWordLoop
		
		mov dx, [di]
		push dx ; letter
		mov al, ind1
		mov dl, 3
		mul dl
		add ax, _startX
		push ax
		call DrawDarkGrayRect
		
		@@ContUserLoop:
		pop cx
		inc di
		inc ind1
		loop @@UserWordLoop
			
	@@ret:
	
	mov sp, bp
	pop bp
	ret 2
endp ChangeColors

;#####################################
;
; Draws a yellow rect with the letter in the place
; Letter - the letter
; Xpos - the place to draw
;
;#####################################
Letter = [byte bp + 6]
Xpos = [word bp + 4]
proc DrawYellowRect

	push bp
	mov bp, sp
	push dx
	
	xor dx, dx
	mov dl, Letter
	
	push 43
	push dx
	push Xpos
	push [CurrentLineY]
	push 18
	push 18
	push 1
	call DrawRectWithLetter
	
	pop dx
	
	mov sp, bp
	pop bp
	ret 4
endp DrawYellowRect

;#####################################
;
; Draws a dark gray rect with the letter in the place
; Letter - the letter
; Xpos - the place to draw
;
;#####################################
Letter = [byte bp + 6]
Xpos = [word bp + 4]
proc DrawDarkGrayRect

	push bp
	mov bp, sp
	push dx
	
	xor dx, dx
	mov dl, Letter
	
	push 23
	push dx
	push Xpos
	push [CurrentLineY]
	push 18
	push 18
	push 1
	call DrawRectWithLetter
	
	pop dx
	
	mov sp, bp
	pop bp
	ret 4
endp DrawDarkGrayRect

;#####################################
;
; Draws a green rect with the letter in the place
; Letter - the letter
; Xpos - the place to draw
;
;#####################################
Letter = [byte bp + 6]
Xpos = [word bp + 4]
proc DrawGreenRect

	push bp
	mov bp, sp
	push dx
	
	xor dx, dx
	mov dl, Letter
	
	push 2
	push dx
	push Xpos
	push [CurrentLineY]
	push 18
	push 18
	push 1
	call DrawRectWithLetter
	
	pop dx
	
	mov sp, bp
	pop bp
	ret 4
endp DrawGreenRect

;#####################################
;
; Clears a row on the gameboard
; x - the start position of the x
; y - the start position of the y
; _width - the width of the row to clear
; height - the height of the row to clear
;
;#####################################
x equ [byte bp + 10]
y equ [byte bp + 8]
_width equ [word bp + 6]
height equ [word bp + 4]
proc ClearRow

	push bp
	mov bp, sp
	
	push ax
	push es
	push bx
	push dx
	push cx
	push si
	
	mov ax, 0A000h
	mov es, ax
	
	; Calculates the total number of bytes that will be cleared
	mov bl, 8
	xor ax, ax
	mov al, y
	mul bl
	
	sub ax, 5
	mov bx, 320
	xor dx, dx
	mul bx
	
	mov cx, ax
	
	xor ax, ax
	mov al, x
	mov bl, 8
	mul bl
	sub al, 5
	add ax, cx
	mov si, ax
	; END of calc
	
	
	mov cx, height
	@@firstloop:
		push si
		push cx

		mov cx, _width
		@@secondloop:
			mov [byte es:si], 0
			inc si
			loop @@secondloop
	
		pop cx
		pop si
		add si, 320
		loop @@firstloop
	
	
	pop si
	pop cx
	pop dx
	pop bx
	pop es
	pop ax
	
	pop bp
	ret 8
endp ClearRow

;#####################################
;
; Adds the letter to the var currentLine
; Letter - the letter to add
;
;#####################################
Letter = [byte bp + 4]
proc AddLetterToCurrentLine
	
	push bp
	mov bp, sp
	
	mov bx, offset currentLine
	
	xor cx, cx
	mov cl, [ModeChosen]
	@@loopTillZero:
		cmp [byte bx], 0
		jne @@contLoop
		mov al, letter
		mov [bx], al
		jmp @@leave
		
		@@contLoop:
			inc bx
			loop @@loopTillZero
			
	@@leave:
	
	pop bp
	ret 2
endp AddLetterToCurrentLine

;#################################################
;
; Prints to the screen the currentLine
; _CurrentX - the x pos to print the rect with letter
;
;#################################################
_CurrentX = [word bp - 2]
proc PrintCurrentLine
	
	push bp
	mov bp, sp
	
	sub sp, 2
	
	mov ax, [startX]
	mov _CurrentX, ax
	
	
	xor cx, cx
	mov bx, offset currentLine
	mov cl, [ModeChosen]
	@@LoopLetters:
		
		cmp [byte bx], 0
		je @@ret
		
		push 27
		push [bx]
		push _CurrentX
		push [CurrentLineY]
		push 18
		push 18
		push 1
		call DrawRectWithLetter
		
		inc bx
		add _CurrentX, 3
		loop @@LoopLetters
		
	@@ret:
	mov sp, bp
	pop bp
	ret 
endp PrintCurrentLine

;###################################################
;
; Gets a random word from the database 
; of the words (in the matching database to the gamemode)
;
;###################################################
FileHandle2 = [bp + 4]
proc GetRandomWord
	
	push bp
	mov bp, sp
	
	push FileHandle2
	call GetWordCount ; in ax
	
	mov bx, 0
	dec ax
	mov dx, ax
	call RandomByCsWord
	
	; the index of the word in bytes
	xor dx, dx
	mov bl, [ModeChosen]
	inc bl ; cus enter
	inc bl
	mul bx
	
	
	; Skips the pointer in the file to where the word is
	mov cx, dx
	mov dx, ax
	
	mov ah, 42h
	mov al, 0
	mov bx, FileHandle2
	int 21h
	jc @@ErrFile
	jmp @@cont
@@ErrFile:
	
	call printAxDec

@@cont:
	
	; Puts the random word in its place
	xor ax, ax
	mov al, [ModeChosen]
	push offset RandomWord
	push ax
	push FileHandle2
	call ReadFile
	
	pop bp
	ret 2
endp GetRandomWord

;#####################################
;
; Gets the count of words in the database
; of the words according to the gamemode
; returns in ax
;
;#####################################

FileHandle2 = [bp + 4]
proc GetWordCount
	
	push bp
	mov bp, sp
	
	; Get file length
	mov ah, 42h
	mov al, 2
	mov bx, FileHandle2
	xor cx, cx
	xor dx, dx
	int 21h
	
	inc ax
	xor bx, bx
	mov bl, [ModeChosen]
	inc bl
	inc bl
	div bx
	inc ax
	
	pop bp
	ret 2
endp GetWordCount


;#####################################
;
; Draw the gameboard to the screen 
; according to the gamemode chosen
; boardX - the x pos to print the rects
; boardY - the y pos to print the rects
;
;#####################################
boardX = [word bp - 2]
boardY = [word bp - 4]
proc DrawGameBoard
	
	push bp
	mov bp, sp
	
	sub sp, 4
	
	mov ax, [startX]
	mov boardX, ax
	
	mov ax, [startY]
	mov boardY, ax
	
	
	xor cx, cx
	mov cl, 6
	@@lineLoop:
	
		push cx
		
		xor cx, cx
		mov cl, [ModeChosen]
		
		push boardX
		@@colLoop:
			
			push 27
			push ' '
			push boardX
			push boardY
			push 18
			push 18
			push 1
			call DrawRectWithLetter
			
			add boardX, 3
			loop @@colLoop
		
		pop boardX
		add boardY, 3
		pop cx
		
		loop @@lineLoop
	
	;FOR CHEATS ONLY
	;mov ah, 2
	;mov bh, 0
	;xor dx, dx
	;xor cx, cx
	;int 10h
	
	;mov dx, offset RandomWord
	;mov ah, 9
	;int 21h
	
	mov sp, bp
	pop bp
	ret 4
endp DrawGameBoard

;#####################################
;
; Shows the main screen on the screen
; and handles the situation according
; to the button the user pressed
;
;#####################################
proc ShowMainScreen

	call SetGraphic
	
	mov dx, offset FileName
	mov [BmpLeft],0
	mov [BmpTop],0
	mov [BmpColSize], BMP_WIDTH
	mov [BmpRowSize] ,BMP_HEIGHT
	
	
	mov dx, offset FileName
	call OpenShowBmp
	cmp [ErrorFile],1
	jne @@cont 
	jmp @@exitError
@@cont:

	
    jmp @@return
	
@@exitError:
	mov ax,2
	int 10h
	
    mov dx, offset BmpFileErrorMsg
	mov ah,9
	int 21h
	
@@return:
	
	
	
	mov ax, 1
	int 33h
	; wait for left click action
	xor bx, bx
waitForLeftClick:

	mov ax, 3
	int 33h
	
	; So the player cant write in main menu
	mov ah, 1
	int 16h
	jz @@NotPressed
	mov ah, 0
	int 16h
	@@NotPressed:
	
	cmp bx, 1
	jne waitForLeftClick

	xor ax, ax
	call CheckClickInMAinScreen
	cmp ax, 0 ; checks if clicked
	je waitForLeftClick
	
	cmp ax, 8 ; Exit button
	jne @@NotExit
	
	mov ax, 2
	int 10h
	mov ax, 4c00h
	int 21h
	
	@@NotExit:
	
	cmp ax, 11 ; HTP button
	jne @@NotHowToPlay
	
	call PrintHowToPlay
	call StartGame
	
	@@NotHowToPlay:
	
	cmp ax, 5 ; five letters button
	jne @@NotFive
	
	mov [ModeChosen], al
	
	@@NotFive:
	
	cmp ax, 4; four letters button
	jne @@NotFour
	
	mov [ModeChosen], al
	
	@@NotFour:
	
	cmp ax, 6 ; six letters button
	jne @@NotSix
	
	mov [ModeChosen], al
	
	@@NotSix:
	
	cmp ax, 7 ; seven letters button
	jne @@NotSeven
	
	mov [ModeChosen], al
	
	@@NotSeven:
	
	cmp ax, 9 ; Leaderboard button
	jne @@NotLeaderboard
	
	call ShowLeaderboard
	call StartGame
	
	@@NotLeaderboard:
	
	mov ax, 2
	int 33h

	ret
endp ShowMainScreen

;######################################
; returns in ax:
;
; clicked 4 letters - 4
; clicked 5 letters - 5
; clicked 6 letters - 6
; clicked 7 letters - 7
; clicked Exit (X) button - 8
; clicked LeaderBoard - 9
; 
; clicked how to play words - 11
;######################################

proc CheckClickInMAinScreen
	
	; Check Clicked 5
	push 6
	push 89
	push 74
	push 109
	call IsIn ; in ax 1 if in
	cmp ax, 1
	jne @@Next_One
	
	mov ax, 5
	jmp @@ret
	
	@@Next_One:
	
	; Check Clicked Exit
	push 280
	push 0
	push 320
	push 39
	call IsIn ; in ax 1 if in
	cmp ax, 1
	jne @@Next_Two
	
	mov ax, 8
	jmp @@ret
	
	@@Next_Two:
	
	; Check Clicked To Play
	push 249
	push 149
	push 318
	push 171
	call IsIn ; in ax 1 if in
	cmp ax, 1
	jne @@Next_Three
	
	mov ax, 11
	jmp @@ret
	
	@@Next_Three:
	
	; Check Clicked 4
	push 6
	push 61
	push 74
	push 82
	call IsIn ; in ax 1 if in
	cmp ax, 1
	jne @@Next_four
	
	mov ax, 4
	jmp @@ret
	
	@@Next_four:
	
	; Check Clicked 6
	push 6
	push 117
	push 74
	push 138
	call IsIn ; in ax 1 if in
	cmp ax, 1
	jne @@Next_Five
	
	mov ax, 6
	jmp @@ret
	
	@@Next_Five:
	
	; Check Clicked 7
	push 6
	push 144
	push 74
	push 165
	call IsIn ; in ax 1 if in
	cmp ax, 1
	jne @@Next_Seven
	
	mov ax, 7
	jmp @@ret
	
	@@Next_Seven:
	
	push 249
	push 175
	push 318
	push 197
	call IsIn ; in ax 1 if in
	cmp ax, 1
	jne @@Next_Eight
	
	mov ax, 9
	jmp @@ret
	
	@@Next_Eight:
	
	@@ret:
	ret
endp CheckClickInMAinScreen


;#####################################
;
; Checks if the click with the mouse
; is within the coords
;
; TopLeftX - the top left x 
; TopLeftY - the top left y 
; bottomRightx - the bottom right x 
; bottomRightY - the bottom right y 
;
;#####################################
; returns in ax 1 or 0
TopLeftX = [word bp + 10]
TopLeftY = [word bp + 8]
bottomRightx = [word bp + 6]
bottomRightY = [word bp + 4]
proc IsIn
	
	push bp
	mov bp, sp
	
	push cx
	push dx
	
	shr cx, 1
	dec dx
	
	; Check if in top left
	cmp cx, TopLeftX
	jb @@NotIn
	
	cmp dx, TopLeftY
	jb @@NotIn
	
	; Check if in bottom right
	
	cmp cx, bottomRightx
	ja @@NotIn
	
	cmp dx, bottomRightY
	ja @@NotIn
	; means in
	mov ax, 1
	jmp @@cont
	
@@NotIn:
	
	xor ax, ax
	
@@cont:
	
	pop dx
	pop cx
	pop bp
	ret 8
endp IsIn

;#####################################
;
; Shows the bmp of the how to play screen
; on the screen and wait till user
; clicked on the X button
;
;#####################################
proc PrintHowToPlay
	
	call SavePalette
	
	call SetGraphic
	mov dx, offset File_Name_HowToPlay
	mov [BmpLeft],0
	mov [BmpTop],0
	mov [BmpColSize], BMP_WIDTH
	mov [BmpRowSize] ,BMP_HEIGHT
	
	call OpenShowBmp
	cmp [ErrorFile],1
	jne @@cont 
	jmp @@exitError
@@cont:

	
    jmp @@return
	
@@exitError:
	mov ax,2
	int 10h
	
    mov dx, offset BmpFileErrorMsg
	mov ah,9
	int 21h
	
@@return:
	
	; wait for left click action
	mov ax, 1
	int 33h
	xor bx, bx
@@waitForLeftClick:

	mov ax, 3
	int 33h
	
	cmp bx, 1
	jne @@waitForLeftClick
	
	; The X button 
	push 293
	push 8
	push 304
	push 18
	call IsIn
	cmp ax, 0
	je @@waitForLeftClick
	
	call LoadPalette
	
	ret
endp PrintHowToPlay

;#####################################
;
; Draws a rect with a letter in the
; correct pos, in the correct color,
; correct height and width, and if
; needed with an outline
;
;#####################################
Bcolor equ [byte bp + 16]
_letter equ [byte bp + 14]
x equ [byte bp + 12]
y equ [byte bp + 10]
_width equ [word bp + 8]
height equ [word bp + 6]
outline equ [word bp + 4]
proc DrawRectWithLetter

	push bp
	mov bp, sp
	
	push ax
	push es
	push bx
	push dx
	push cx
	push si
	
	
	mov ax, 0A000h
	mov es, ax
	
	; Prints the Letter in correct spot
	mov dl, x
	mov dh, y
	mov ah, 2
	mov bh, 0
	int 10h
	
	mov ah, 0Eh
	mov al, _letter
	mov bh, 0
	mov bl, 17
	int 10h
	
	;#####################################################
	;	
	;	calculates where to start drawing the "box" for the
	;	letter in the game because the X:Y ratio is different
	;	between text mode and graphics mode
	;	
	;	
	;#################### Start CALC #####################
	mov bl, 8
	xor ax, ax
	mov al, y
	mul bl
	
	sub ax, 5
	mov bx, 320
	xor dx, dx
	mul bx
	
	mov cx, ax
	
	xor ax, ax
	mov al, x
	mov bl, 8
	mul bl
	sub al, 5
	add ax, cx
	mov si, ax
	;#################### END CALC #####################
	
	cmp outline, 1
	jne @@WithoutOutline
	mov cx, height
	@@firstloop:
		push si
		push cx
		
		mov bx, cx ; so i can do height check
		
		mov [byte es:si], 20 ; OutLine

		mov cx, _width
		@@secondloop:
		
			cmp [byte es:si], 0
			jne @@skipdraw
				
				cmp bx, 1
				jne @@NotEnd
				
				
				mov [byte es:si], 20 ; OutLine
				jmp @@skipdraw
				
				@@NotEnd:
				
					mov al, Bcolor
					mov [ es:si], al ; usually 27
				
			@@skipdraw:
			inc si
			loop @@secondloop
	
		pop cx
		pop si
		add si, 320
		loop @@firstloop
		
		jmp @@ret
		
		@@WithoutOutline:
		
			mov cx, height
			@@NoOLfirstloop:
				push si
				push cx

				mov cx, _width
				@@NoOLsecondloop:
				
					cmp [byte es:si], 0
					jne @@NoOLskipdraw
						
							mov al, Bcolor
							mov [byte es:si], al ; usually 27
						
					@@NoOLskipdraw:
					inc si
					loop @@NoOLsecondloop
	
	@@ret:
	pop si
	pop cx
	pop dx
	pop bx
	pop es
	pop ax
	
	pop bp
	
	ret 14
endp DrawRectWithLetter

;#####################################
;
; Paints the whole screen in a color
; Gets in ax the color
;
;#####################################
proc ClearScreen
	
	push si
	push ax
	mov ax, 0A000h
	mov es, ax
	pop ax
	
	xor si, si
	
	mov cx, 320 * 200
@@loop:
	mov [byte es:si], al
	inc si
	loop @@loop

	pop si
	ret
endp ClearScreen

;########################################
;
; Files Procs:
; Access modes:
; 00 - read only
; 01 - write only
; 02 - read/write
;
; returns in ax the handle of the file
; if error show number of error on screen
;
;########################################

AccessMode = [byte bp + 6]  
OffsetFileName = [word bp + 4]
proc OpenFile

	push bp
    mov bp, sp
	
	mov ah, 3Dh
	mov al, AccessMode
	mov dx, OffsetFileName
	int 21h
	jc @@ErrFile
	jmp @@cont
@@ErrFile:
	
	call printAxDec

@@cont:
	
	pop bp
	ret 4
endp OpenFile



;########################################
;
; push the file handle to close
; if error show number of error on screen
;
;########################################

FileHandle2 = [bp + 4]
proc CloseFile

	push bp
    mov bp, sp
	
	mov ah, 3Eh
	mov bx, FileHandle2
	int 21h
	jc @@ErrFile
	jmp @@cont
@@ErrFile:
	
	call printAxDec

@@cont:
	
	pop bp
	ret 2
endp CloseFile

;########################################
;
; if error show number of error on screen
; returns in ax the number of bytes read
;
;########################################
ReadBuffer = [bp + 8]
ReadLength = [bp + 6]
FileHandle2 = [bp + 4]
proc ReadFile
	
	push bp
    mov bp, sp
	push bx
	push cx
	push dx
	
	mov ah, 3fh
	mov bx, FileHandle2
	mov cx, ReadLength
	mov dx, ReadBuffer
	int 21h
	jc @@ErrFile
	jmp @@cont
@@ErrFile:

	call printAxDec

@@cont:
	
	pop dx
	pop cx
	pop bx
	pop bp
	ret 6
endp ReadFile
	
;#####################################
;
; Saves the current pallete in PaletteBackup
;
;#####################################
proc SavePalette

	mov dx, 03C7h
	mov al, 0
	out dx, al
	mov dx, 03C9h
	mov cx, 256 * 3
	
	mov bx, offset PaletteBackup
	
	@@loop:
		
		in al, dx
		mov [bx], al
		inc bx
		
		loop @@loop

	ret
endp SavePalette

;#####################################
;
; Loads the saved pallete that is in PaletteBackup
; to the screen
;
;#####################################
proc LoadPalette

	mov cx, 256 * 3
    mov dx, 3C8h
    mov al, 0
    out dx, al
    inc dx
	
	mov bx, offset PaletteBackup
	
	@@loopPalette:
	
		mov al, [bx]
		out dx,al
		inc bx

		loop @@loopPalette

	ret
endp LoadPalette
  
;#####################################
;
; Sets to graphics mode
;
;#####################################
proc SetGraphic
	mov ax,13h   ; 320 X 200 
				 ;Mode 13h is an IBM VGA BIOS mode. It is the specific standard 256-color mode 
	int 10h
	ret
endp SetGraphic

	
; BMP THINGS
;
;
; bmp
;
;
;
;
;#####################################
;
; Opens the bmp and shows it on the screen
;
;#####################################
proc OpenShowBmp near
	
	 
	call OpenBmpFile
	cmp [ErrorFile],1
	je @@ExitProc
	
	call ReadBmpHeader
	
	call ReadBmpPalette
	
	call CopyBmpPalette
	
	call  ShowBmp
	
	 
	call CloseBmpFile

@@ExitProc:
	ret
endp OpenShowBmp

 

; input dx filename to open
proc OpenBmpFile	near						 
	mov ah, 3Dh
	xor al, al
	int 21h
	jc @@ErrorAtOpen
	mov [FileHandle], ax
	jmp @@ExitProc
	
@@ErrorAtOpen:
	mov [ErrorFile],1
	call printAxDec
	mov ah, 1
	int 21h
@@ExitProc:	
	ret
endp OpenBmpFile

proc CloseBmpFile near
	mov ah,3Eh
	mov bx, [FileHandle]
	int 21h
	ret
endp CloseBmpFile

; Read 54 bytes the Header
proc ReadBmpHeader	near					
	push cx
	push dx
	
	mov ah,3fh
	mov bx, [FileHandle]
	mov cx,54
	mov dx,offset Header
	int 21h
	
	pop dx
	pop cx
	ret
endp ReadBmpHeader



proc ReadBmpPalette near ; Read BMP file color palette, 256 colors * 4 bytes (400h)
						 ; 4 bytes for each color BGR + null)			
	push cx
	push dx
	
	mov ah,3fh
	mov cx,400h
	mov dx,offset Palette
	int 21h
	
	pop dx
	pop cx
	
	ret
endp ReadBmpPalette


; Will move out to screen memory the colors
; video ports are 3C8h for number of first color
; and 3C9h for all rest
proc CopyBmpPalette		near					
										
	push cx
	push dx
	
	mov si,offset Palette
	mov cx,256
	mov dx,3C8h
	mov al,0  ; black first							
	out dx,al ;3C8h
	inc dx	  ;3C9h
CopyNextColor:
	mov al,[si+2] 		; Red				
	shr al,2 			; divide by 4 Max (cos max is 63 and we have here max 255 ) (loosing color resolution).				
	out dx,al 						
	mov al,[si+1] 		; Green.				
	shr al,2            
	out dx,al 							
	mov al,[si] 		; Blue.				
	shr al,2            
	out dx,al 							
	add si,4 			; Point to next color.  (4 bytes for each color BGR + null)				
								
	loop CopyNextColor
	
	pop dx
	pop cx
	
	ret
endp CopyBmpPalette

 
proc ShowBMP 
; BMP graphics are saved upside-down.
; Read the graphic line by line (BmpRowSize lines in VGA format),
; displaying the lines from bottom to top.
	push cx
	
	mov ax, 0A000h
	mov es, ax
	
	mov cx,[BmpRowSize]
	
 
	mov ax,[BmpColSize] ; row size must dived by 4 so if it less we must calculate the extra padding bytes
	xor dx,dx
	mov si,4
	div si
	cmp dx,0
	mov bp,0
	jz @@row_ok
	mov bp,4
	sub bp,dx

@@row_ok:	
	mov dx,[BmpLeft]
	
@@NextLine:
	push cx
	push dx
	
	mov di,cx  ; Current Row at the small bmp (each time -1)
	add di,[BmpTop] ; add the Y on entire screen
	
 
	; next 5 lines  di will be  = cx*320 + dx , point to the correct screen line
	mov cx,di
	shl cx,6
	shl di,8
	add di,cx
	add di,dx
	 
	; small Read one line
	mov ah,3fh
	mov cx,[BmpColSize]  
	add cx,bp  ; extra  bytes to each row must be divided by 4
	mov dx,offset ScrLine
	int 21h
	; Copy one line into video memory
	cld ; Clear direction flag, for movsb
	mov cx,[BmpColSize]  
	mov si,offset ScrLine
	rep movsb ; Copy line to the screen
	
	pop dx
	pop cx
	 
	loop @@NextLine
	
	pop cx
	ret
endp ShowBMP
;
;
;
; END BMP THINGS

;#####################################
;
; Prints the value in ax int decimal to
; the screen
;
;#####################################
proc printAxDec  
	   
       push bx
	   push dx
	   push cx
	   push ax
	           	   
       mov cx,0   ; will count how many time we did push 
       mov bx,10  ; the divider
   
put_next_to_stack:
       xor dx,dx
       div bx
       add dl,30h
	   ; dl is the current LSB digit 
	   ; we cant push only dl so we push all dx
       push dx    
       inc cx
       cmp ax,9   ; check if it is the last time to div
       jg put_next_to_stack

	   cmp ax,0
	   jz pop_next_from_stack  ; jump if ax was totally 0
       add al,30h  
	   mov dl, al    
  	   mov ah, 2h
	   int 21h        ; show first digit MSB
	       
pop_next_from_stack: 
       pop ax    ; remove all rest LIFO (reverse) (MSB to LSB)
	   mov dl, al
       mov ah, 2h
	   int 21h        ; show all rest digits
       loop pop_next_from_stack
	
		pop ax
	   pop cx
	   pop dx
	   pop bx
	   
       ret
endp printAxDec 


;#####################################
;
; Makes a random number by Cs
;
;#####################################
; Randoms
proc RandomByCsWord
    push es
	push si
	push di
 
	
	mov ax, 40h
	mov	es, ax
	
	sub dx,bx  ; we will make rnd number between 0 to the delta between bx and dx
			   ; Now dx holds only the delta
	cmp dx,0
	jz @@ExitP
	
	push bx
	
	mov di, [word RndCurrentPos]
	call MakeMaskWord ; will put in si the right mask according the delta (bh) (example for 28 will put 31)
	
@@RandLoop: ;  generate random number 
	mov bx, [es:06ch] ; read timer counter
	
	mov ax, [word cs:di] ; read one word from memory (from semi random bytes at cs)
	xor ax, bx ; xor memory and counter
	
	; Now inc di in order to get a different number next time
	inc di
	inc di
	cmp di,(EndOfCsLbl - start - 2)
	jb @@Continue
	mov di, offset start
@@Continue:
	mov [word RndCurrentPos], di
	
	and ax, si ; filter result between 0 and si (the nask)
	
	cmp ax,dx    ;do again if  above the delta
	ja @@RandLoop
	pop bx
	add ax,bx  ; add the lower limit to the rnd num
		 
@@ExitP:
	
	pop di
	pop si
	pop es
	ret
endp RandomByCsWord



Proc MakeMaskWord    
    push dx
	
	mov si,1
    
@@again:
	shr dx,1
	cmp dx,0
	jz @@EndProc
	
	shl si,1 ; add 1 to si at right
	inc si
	
	jmp @@again
	
@@EndProc:
    pop dx
	ret
endp  MakeMaskWord
	
EndOfCsLbl:
END start


