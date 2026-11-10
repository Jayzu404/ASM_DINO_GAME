.MODEL SMALL
.8086
JUMPS
.STACK 100h

SCREEN_W            EQU 320
SCREEN_H            EQU 200
SCREEN_WORDS        EQU 32000
BUFFER_PARAGRAPHS   EQU 0FA0h
TEXT_MODE           EQU 0003h
GRAPHICS_MODE       EQU 0013h
VIDEO_SEGMENT       EQU 0A000h
GROUND_Y            EQU 164
GROUND_LINE_H       EQU 2
GROUND_MARK_Y       EQU 169
GROUND_MARK_W       EQU 9
GROUND_MARK_H       EQU 2
GROUND_MARK_GAP     EQU 40
GROUND_MARK_COUNT   EQU 9
DINO_X              EQU 44
DINO_BODY_COLOR     EQU 0Fh
DINO_DETAIL_COLOR   EQU 00h
CLOUD_COUNT         EQU 4
CLOUD_WIDTH         EQU 27
GAME_MENU           EQU 0
GAME_RUNNING        EQU 1
GAME_PAUSED         EQU 2
GAME_OVER           EQU 3
ANIMATION_FRAMES    EQU 4
FRAME_RETRACES      EQU 2

JUMP_VELOCITY       EQU 11
GRAVITY             EQU 1
START_SPEED         EQU 5
MAX_SPEED           EQU 10
SPEED_STEP_SCORE    EQU 100
SCORE_FRAMES        EQU 3
GAME_OVER_DELAY     EQU 25
MIN_GAP_FRAMES      EQU 24
GAP_RANGE_FRAMES    EQU 30
FIRST_SPAWN_DELAY   EQU 150
BIRD_MIN_SCORE      EQU 150
BIRD_FLAP_FRAMES    EQU 4

OBSTACLE_SLOTS      EQU 3
OBS_NONE            EQU 0FFh
KIND_CACTUS_COUNT   EQU 4
KIND_ALL_COUNT      EQU 6
HIT_MARGIN_X        EQU 2
HIT_MARGIN_Y        EQU 2

JUMP_TONE           EQU 1500
JUMP_TONE_FRAMES    EQU 3
MILESTONE_TONE      EQU 800
MILESTONE_FRAMES    EQU 5
DEATH_TONE          EQU 4000
DEATH_TONE_FRAMES   EQU 14

COLOR_BLACK         EQU 00h
COLOR_BLUE          EQU 01h
COLOR_GREEN         EQU 02h
COLOR_BROWN         EQU 06h
COLOR_LIGHT_GRAY    EQU 07h
COLOR_DARK_GRAY     EQU 08h
COLOR_LIGHT_BLUE    EQU 09h
COLOR_LIGHT_GREEN   EQU 0Ah
COLOR_LIGHT_CYAN    EQU 0Bh
COLOR_YELLOW        EQU 0Eh
COLOR_WHITE         EQU 0Fh

.DATA

titleText           DB 'DINO RUN',0
menuJumpText        DB 'SPACE OR UP - JUMP',0
startText           DB 'PRESS ENTER TO START',0
menuQuitText        DB 'ESC - QUIT',0
menuFooterText      DB 'KEEP RUNNING!',0
runningPauseText    DB 'P: PAUSE',0
runningMenuText     DB 'ESC: MENU',0
hiText              DB 'HI ',0
spaceText           DB ' ',0
pausedTitle         DB 'PAUSED',0
pausedResumeText    DB 'P OR ENTER - RESUME',0
gameOverTitle       DB 'GAME OVER',0
gameOverScoreText   DB 'SCORE ',0
newBestText         DB 'NEW BEST!',0
gameOverRetryText   DB 'ENTER - RESTART',0
gameOverQuitText    DB 'ESC - QUIT',0

gameState           DB GAME_MENU
exitRequested       DB 0
keyJump             DB 0
keyPause            DB 0
keyEnter            DB 0
keyEsc              DB 0
runFrame            DB 0
birdFrame           DB 0
birdCounter         DB 0
scoreTick           DB 0
jumpActive          DB 0
hitFlag             DB 0
newBestFlag         DB 0
gameOverDelay       DB 0
soundTimer          DB 0
textColor           DB COLOR_WHITE
fillColor           DB COLOR_BLACK

groundOffset        DW 0
dashIndex           DW 0
animationCounter    DW 0
animationRate       DW 3

gameSpeed           DW START_SPEED
nextSpeedScore      DW SPEED_STEP_SCORE
spawnCountdown      DW FIRST_SPAWN_DELAY
score               DW 0
bestScore           DW 0
randSeed            DW 1234h
jumpHeight          DW 0
jumpVelocity        DW 0

boxLeft             DW 0
boxRight            DW 0
boxTop              DW 0
boxBottom           DW 0

obsX                DW OBSTACLE_SLOTS DUP (0)
obsKind             DB OBSTACLE_SLOTS DUP (OBS_NONE)
objX                DW 0
objY                DW 0

kindWidth           DW 11, 15, 25, 39, 21, 21
kindHeight          DW 22, 32, 22, 22, 14, 14
kindTop             DW 142, 132, 142, 142, 140, 104
kindSpeed           DW 0, 0, 0, 0, 1, 1

cloudX              DW 28, 112, 204, 278
cloudY              DW 26, 43, 19, 58
cloudSpeed          DW 1, 2, 1, 1
cloudBaseX          DW 0
cloudBaseY          DW 0

rectX               DW 0
rectY               DW 0
rectW               DW 0
rectH               DW 0
rectColor           DB COLOR_WHITE

digitDivisors       DW 10000, 1000, 100, 10, 1

backSeg             DW 0
bgSeg               DW 0
drawSeg             DW 0
fontSeg             DW 0
fontOff             DW 0
textX               DW 0
textY               DW 0
glyphBuf            DB 8 DUP (0)

.CODE

; program entry: resize memory, allocate buffers, then run the main loop
start PROC
    mov dx, es
    mov ax, @data
    mov ds, ax
    cld

    ; shrink the program block so DOS can hand out memory for the buffers
    mov ax, ss
    sub ax, dx
    mov bx, sp
    add bx, 15
    mov cl, 4
    shr bx, cl
    add bx, ax
    mov ah, 4Ah
    int 21h
    jc StartFail

    ; one allocation holds the back buffer and the cached background
    mov bx, BUFFER_PARAGRAPHS*2
    mov ah, 48h
    int 21h
    jc StartFail
    mov backSeg, ax
    mov drawSeg, ax
    add ax, BUFFER_PARAGRAPHS
    mov bgSeg, ax

    call InitializeGameData
    call SetVideoMode
    call LoadFont
    call BuildBackground
    call SeedRandom

; main loop: run the handler of the current game state
MainLoop:
    cmp exitRequested, 0
    jne ExitProgram

    cmp gameState, GAME_MENU
    je DispatchMenu

    cmp gameState, GAME_RUNNING
    je DispatchRunning

    cmp gameState, GAME_PAUSED
    je DispatchPaused

    cmp gameState, GAME_OVER
    je DispatchGameOver

    mov gameState, GAME_MENU
    jmp MainLoop

DispatchMenu:
    call MenuLoop
    jmp MainLoop

DispatchRunning:
    call RunningLoop
    jmp MainLoop

DispatchPaused:
    call PauseLoop
    jmp MainLoop

DispatchGameOver:
    call GameOverLoop
    jmp MainLoop

ExitProgram:
    call StopTone
    call RestoreTextMode
    mov ax, 4C00h
    int 21h

StartFail:
    mov ax, 4C01h
    int 21h
start ENDP

; sets the starting values of the whole program
InitializeGameData PROC
    mov gameState, GAME_MENU
    mov exitRequested, 0
    mov runFrame, 0
    mov bestScore, 0
    call ResetRunningState
    ret
InitializeGameData ENDP

; resets everything that changes while a run is playing
ResetRunningState PROC
    push ax
    push bx
    push si

    mov runFrame, 0
    mov birdFrame, 0
    mov birdCounter, 0
    mov scoreTick, 0
    mov jumpActive, 0
    mov hitFlag, 0
    mov newBestFlag, 0
    mov gameOverDelay, 0
    mov groundOffset, 0
    mov animationCounter, 0
    mov score, 0
    mov gameSpeed, START_SPEED
    mov nextSpeedScore, SPEED_STEP_SCORE
    mov spawnCountdown, FIRST_SPAWN_DELAY
    mov jumpHeight, 0
    mov jumpVelocity, 0

    ; empty every obstacle slot
    xor si, si
ClearObstacleLoop:
    mov obsKind[si], OBS_NONE
    mov bx, si
    shl bx, 1
    mov obsX[bx], 0
    inc si
    cmp si, OBSTACLE_SLOTS
    jb ClearObstacleLoop

    ; mix the timer into the seed so every run differs
    call SeedRandom

    pop si
    pop bx
    pop ax
    ret
ResetRunningState ENDP

; switches to 320x200 256 color mode
SetVideoMode PROC
    push ax
    push bx
    mov ax, GRAPHICS_MODE
    int 10h
    mov ax, VIDEO_SEGMENT
    mov es, ax
    pop bx
    pop ax
    ret
SetVideoMode ENDP

; goes back to normal text mode
RestoreTextMode PROC
    push ax
    mov ax, TEXT_MODE
    int 10h
    pop ax
    ret
RestoreTextMode ENDP

; gets the address of the 8x8 ROM font from the BIOS
LoadFont PROC
    push ax
    push bx
    push cx
    push dx
    push bp
    push es
    mov ax, 1130h
    mov bh, 03h
    int 10h
    mov fontSeg, es
    mov fontOff, bp
    pop es
    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret
LoadFont ENDP

; waits for the start of the next vertical retrace
WaitVRetrace PROC
    push ax
    push dx
    mov dx, 3DAh
WaitRetraceEnd:
    in al, dx
    test al, 8
    jnz WaitRetraceEnd
WaitRetraceStart:
    in al, dx
    test al, 8
    jz WaitRetraceStart
    pop dx
    pop ax
    ret
WaitVRetrace ENDP

; copies the back buffer to the screen
BlitScreen PROC
    push ax
    push cx
    push si
    push di
    push ds
    push es

    call WaitVRetrace

    mov ax, backSeg
    mov ds, ax
    mov ax, VIDEO_SEGMENT
    mov es, ax
    xor si, si
    xor di, di
    mov cx, SCREEN_WORDS
    cld
    rep movsw

    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret
BlitScreen ENDP

; waits the needed retraces and shows the finished frame
PresentFrame PROC
    push cx
    mov cx, FRAME_RETRACES-1
    jcxz PresentFrameReady
PresentFrameWait:
    call WaitVRetrace
    loop PresentFrameWait
PresentFrameReady:
    pop cx
    call BlitScreen
    ret
PresentFrame ENDP

; copies the cached background into the back buffer
CopyBackground PROC
    push ax
    push cx
    push si
    push di
    push ds
    push es

    mov ax, backSeg
    mov es, ax
    mov ax, bgSeg
    mov ds, ax
    xor si, si
    xor di, di
    mov cx, SCREEN_WORDS
    cld
    rep movsw

    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret
CopyBackground ENDP

; draws the parts that never move once into the background buffer
BuildBackground PROC
    push ax

    mov ax, bgSeg
    mov drawSeg, ax
    mov fillColor, COLOR_LIGHT_BLUE
    call FillScreen
    call DrawSun
    call DrawFarHills
    call DrawNearHills
    call DrawGroundBase

    mov ax, backSeg
    mov drawSeg, ax

    pop ax
    ret
BuildBackground ENDP

; mixes the BIOS timer into the random seed
SeedRandom PROC
    push ax
    push cx
    push dx
    mov ah, 0
    int 1Ah
    xor dx, cx
    xor randSeed, dx
    pop dx
    pop cx
    pop ax
    ret
SeedRandom ENDP

; AX = range (1 or more), returns AX = 0 .. range-1
GetRandom PROC
    push bx
    push dx

    mov bx, ax
    mov ax, randSeed
    mov dx, 25173
    mul dx
    add ax, 13849
    mov randSeed, ax

    ; the low bits of this generator repeat quickly, so swap the bytes first
    xchg al, ah
    xor dx, dx
    div bx
    mov ax, dx

    pop dx
    pop bx
    ret
GetRandom ENDP

; AX = timer divisor, BL = frames the tone lasts
PlayTone PROC
    push ax
    push dx

    mov dx, ax
    mov soundTimer, bl
    mov al, 0B6h
    out 43h, al
    mov al, dl
    out 42h, al
    mov al, dh
    out 42h, al
    in al, 61h
    or al, 03h
    out 61h, al

    pop dx
    pop ax
    ret
PlayTone ENDP

; turns the speaker off
StopTone PROC
    push ax
    in al, 61h
    and al, 0FCh
    out 61h, al
    pop ax
    ret
StopTone ENDP

; counts down the current tone and stops it when it ends
UpdateSound PROC
    cmp soundTimer, 0
    je UpdateSoundDone
    dec soundTimer
    jnz UpdateSoundDone
    call StopTone
UpdateSoundDone:
    ret
UpdateSound ENDP

; loop of the main menu screen
MenuLoop PROC
MenuLoopStart:
    call UpdateAnimation
    call DrawMenuScreen
    call PollKeyboard

    cmp keyEnter, 0
    jne MenuStartGame

    cmp keyEsc, 0
    jne MenuRequestExit

    jmp MenuLoopStart

MenuStartGame:
    call ResetRunningState
    call FlushKeyboard
    mov gameState, GAME_RUNNING
    ret

MenuRequestExit:
    mov exitRequested, 1
    ret
MenuLoop ENDP

; loop of the running game, handles jump and pause keys
RunningLoop PROC
RunningLoopStart:
    cmp gameState, GAME_RUNNING
    jne RunningLoopDone

    call UpdateWorld
    call DrawRunningScreen
    call PollKeyboard

    cmp gameState, GAME_RUNNING
    jne RunningLoopDone

    cmp keyEsc, 0
    jne RunningToMenu

    cmp keyPause, 0
    jne RunningPause

    cmp keyJump, 0
    je RunningLoopStart

    call StartJump
    jmp RunningLoopStart

; leaves the run and goes back to the main menu
RunningToMenu:
    call StopTone
    mov soundTimer, 0
    call FlushKeyboard
    mov gameState, GAME_MENU
    ret

RunningPause:
    call StopTone
    mov soundTimer, 0
    mov gameState, GAME_PAUSED
    ret

RunningLoopDone:
    ret
RunningLoop ENDP

; loop of the pause screen
PauseLoop PROC
PauseLoopStart:
    call DrawPauseScreen
    call PollKeyboard

    cmp keyEnter, 0
    jne PauseResume

    cmp keyPause, 0
    jne PauseResume

    jmp PauseLoopStart

PauseResume:
    call FlushKeyboard
    mov gameState, GAME_RUNNING
    ret
PauseLoop ENDP

; loop of the game over screen
GameOverLoop PROC
GameOverLoopStart:
    call UpdateSound
    call DrawGameOverScreen
    call PollKeyboard

    ; ignore keys briefly so a jump key press cannot skip the screen
    cmp gameOverDelay, 0
    je GameOverReadKeys
    dec gameOverDelay
    jmp GameOverLoopStart

GameOverReadKeys:
    cmp keyEnter, 0
    jne GameOverRetry

    cmp keyEsc, 0
    jne GameOverQuit

    jmp GameOverLoopStart

GameOverRetry:
    call StopTone
    call ResetRunningState
    call FlushKeyboard
    mov gameState, GAME_RUNNING
    ret

GameOverQuit:
    mov exitRequested, 1
    ret
GameOverLoop ENDP

; switches to the game over state and saves the best score
TriggerGameOver PROC
    push ax
    push bx

    mov gameState, GAME_OVER
    mov gameOverDelay, GAME_OVER_DELAY

    mov ax, score
    cmp ax, bestScore
    jbe TriggerGameOverSound
    mov bestScore, ax
    mov newBestFlag, 1

TriggerGameOverSound:
    mov ax, DEATH_TONE
    mov bl, DEATH_TONE_FRAMES
    call PlayTone
    call FlushKeyboard

    pop bx
    pop ax
    ret
TriggerGameOver ENDP

; reads every pending key so nothing piles up between frames
PollKeyboard PROC
    push ax

    mov keyJump, 0
    mov keyPause, 0
    mov keyEnter, 0
    mov keyEsc, 0

PollKeyboardNext:
    mov ah, 01h
    int 16h
    jz PollKeyboardDone

    mov ah, 00h
    int 16h

    cmp al, 20h
    je PollSetJump
    cmp al, 0Dh
    je PollSetEnter
    cmp al, 1Bh
    je PollSetEsc
    cmp al, 'p'
    je PollSetPause
    cmp al, 'P'
    je PollSetPause

    ; extended keys return ASCII 0, UP arrow has scan code 48h
    cmp al, 0
    jne PollKeyboardNext
    cmp ah, 48h
    je PollSetJump
    jmp PollKeyboardNext

PollSetJump:
    mov keyJump, 1
    jmp PollKeyboardNext

PollSetEnter:
    mov keyEnter, 1
    jmp PollKeyboardNext

PollSetEsc:
    mov keyEsc, 1
    jmp PollKeyboardNext

PollSetPause:
    mov keyPause, 1
    jmp PollKeyboardNext

PollKeyboardDone:
    pop ax
    ret
PollKeyboard ENDP

; throws away all pending keys
FlushKeyboard PROC
    push ax
FlushKeyboardNext:
    mov ah, 01h
    int 16h
    jz FlushKeyboardDone
    mov ah, 00h
    int 16h
    jmp FlushKeyboardNext
FlushKeyboardDone:
    pop ax
    ret
FlushKeyboard ENDP

; one step of the game world
UpdateWorld PROC
    call UpdateAnimation
    call UpdateBirdAnimation
    call UpdateGroundOffset
    call UpdateClouds
    call UpdateJump
    call UpdateObstacles
    call UpdateSpawner
    call UpdateScore
    call UpdateSound
    call CheckCollision

    cmp hitFlag, 0
    je UpdateWorldDone
    call TriggerGameOver
UpdateWorldDone:
    ret
UpdateWorld ENDP

; advances the running animation of the dinosaur
UpdateAnimation PROC
    push ax

    ; the dinosaur holds one pose while it is in the air
    cmp jumpActive, 0
    je UpdateAnimationRun
    mov runFrame, 0
    mov animationCounter, 0
    jmp UpdateAnimationDone

UpdateAnimationRun:
    inc animationCounter
    mov ax, animationCounter
    cmp ax, animationRate
    jb UpdateAnimationDone

    mov animationCounter, 0
    inc runFrame
    cmp runFrame, ANIMATION_FRAMES
    jb UpdateAnimationDone
    mov runFrame, 0

UpdateAnimationDone:
    pop ax
    ret
UpdateAnimation ENDP

; scrolls the ground marks to the left
UpdateGroundOffset PROC
    push ax
    mov ax, groundOffset
    add ax, gameSpeed
    cmp ax, GROUND_MARK_GAP
    jb GroundOffsetReady
    sub ax, GROUND_MARK_GAP
GroundOffsetReady:
    mov groundOffset, ax
    pop ax
    ret
UpdateGroundOffset ENDP

; moves every cloud to the left
UpdateClouds PROC
    push ax
    push bx
    push cx
    push si

    xor si, si
    mov cx, CLOUD_COUNT

UpdateCloudEntry:
    mov ax, cloudX[si]
    sub ax, cloudSpeed[si]

    ; a cloud wraps only after it has fully left the screen
    cmp ax, -CLOUD_WIDTH
    jge CloudPositionNoWrap

    ; it comes back on the right at a new random height
    mov cloudX[si], SCREEN_W
    mov ax, 45
    call GetRandom
    add ax, 14
    mov cloudY[si], ax
    jmp CloudEntryNext

CloudPositionNoWrap:
    mov cloudX[si], ax

CloudEntryNext:
    add si, 2
    loop UpdateCloudEntry

    pop si
    pop cx
    pop bx
    pop ax
    ret
UpdateClouds ENDP

; starts a jump if the dinosaur is on the ground
StartJump PROC
    push ax
    push bx

    cmp jumpActive, 0
    jne StartJumpDone

    mov jumpActive, 1
    mov jumpVelocity, JUMP_VELOCITY
    mov ax, JUMP_TONE
    mov bl, JUMP_TONE_FRAMES
    call PlayTone

StartJumpDone:
    pop bx
    pop ax
    ret
StartJump ENDP

; moves the dinosaur up or down while a jump is active
UpdateJump PROC
    push ax

    cmp jumpActive, 0
    je UpdateJumpDone

    ; move by the current velocity, then let gravity slow it down
    mov ax, jumpHeight
    add ax, jumpVelocity
    mov jumpHeight, ax
    sub jumpVelocity, GRAVITY

    cmp ax, 0
    jg UpdateJumpDone

    ; back on the ground
    mov jumpHeight, 0
    mov jumpVelocity, 0
    mov jumpActive, 0

UpdateJumpDone:
    pop ax
    ret
UpdateJump ENDP

; adds score over time and raises the speed at every step
UpdateScore PROC
    push ax
    push bx

    inc scoreTick
    cmp scoreTick, SCORE_FRAMES
    jb UpdateScoreDone

    mov scoreTick, 0
    inc score

    mov ax, score
    cmp ax, nextSpeedScore
    jb UpdateScoreDone

    add nextSpeedScore, SPEED_STEP_SCORE
    mov ax, MILESTONE_TONE
    mov bl, MILESTONE_FRAMES
    call PlayTone

    cmp gameSpeed, MAX_SPEED
    jae UpdateScoreDone
    inc gameSpeed

UpdateScoreDone:
    pop bx
    pop ax
    ret
UpdateScore ENDP

; flaps the bird wings every few frames
UpdateBirdAnimation PROC
    inc birdCounter
    cmp birdCounter, BIRD_FLAP_FRAMES
    jb UpdateBirdDone
    mov birdCounter, 0
    xor birdFrame, 1
UpdateBirdDone:
    ret
UpdateBirdAnimation ENDP

; moves every obstacle to the left and frees the ones that left the screen
UpdateObstacles PROC
    push ax
    push bx
    push di
    push si

    xor si, si
UpdateObstacleLoop:
    cmp obsKind[si], OBS_NONE
    je UpdateObstacleNext

    mov bl, obsKind[si]
    xor bh, bh
    shl bx, 1
    mov di, si
    shl di, 1

    mov ax, obsX[di]
    sub ax, gameSpeed
    sub ax, kindSpeed[bx]
    mov obsX[di], ax

    ; free the slot once the right edge has left the screen
    add ax, kindWidth[bx]
    cmp ax, 0
    jg UpdateObstacleNext
    mov obsKind[si], OBS_NONE

UpdateObstacleNext:
    inc si
    cmp si, OBSTACLE_SLOTS
    jb UpdateObstacleLoop

    pop si
    pop di
    pop bx
    pop ax
    ret
UpdateObstacles ENDP

; creates a new obstacle when the spawn countdown reaches zero
UpdateSpawner PROC
    push ax
    push bx
    push cx
    push dx
    push di
    push si

    mov ax, gameSpeed
    sub spawnCountdown, ax
    cmp spawnCountdown, 0
    jg UpdateSpawnerDone

    ; look for a free slot, wait for the next frame if all are busy
    xor si, si
SpawnFindSlot:
    cmp obsKind[si], OBS_NONE
    je SpawnSlotFound
    inc si
    cmp si, OBSTACLE_SLOTS
    jb SpawnFindSlot
    jmp UpdateSpawnerDone

SpawnSlotFound:
    ; birds only appear after the player has reached a certain score
    mov ax, KIND_CACTUS_COUNT
    cmp score, BIRD_MIN_SCORE
    jb SpawnKindReady
    mov ax, KIND_ALL_COUNT
SpawnKindReady:
    call GetRandom
    mov obsKind[si], al
    mov di, si
    shl di, 1
    mov obsX[di], SCREEN_W

    ; distance to the next spawn = width + minimum gap + random extra gap
    mov bl, al
    xor bh, bh
    shl bx, 1
    mov cx, kindWidth[bx]

    mov ax, gameSpeed
    mov bx, GAP_RANGE_FRAMES
    mul bx
    inc ax
    call GetRandom
    add cx, ax

    mov ax, gameSpeed
    mov bx, MIN_GAP_FRAMES
    mul bx
    add cx, ax

    add spawnCountdown, cx

UpdateSpawnerDone:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
UpdateSpawner ENDP

; checks the two boxes of the dinosaur against every obstacle
CheckCollision PROC
    push ax

    mov hitFlag, 0

    ; body and legs
    mov boxLeft, DINO_X+3
    mov boxRight, DINO_X+22
    mov ax, 137
    sub ax, jumpHeight
    mov boxTop, ax
    mov ax, 162
    sub ax, jumpHeight
    mov boxBottom, ax
    call TestBoxAgainstObstacles
    cmp hitFlag, 0
    jne CheckCollisionDone

    ; neck and head
    mov boxLeft, DINO_X+23
    mov boxRight, DINO_X+40
    mov ax, 126
    sub ax, jumpHeight
    mov boxTop, ax
    mov ax, 139
    sub ax, jumpHeight
    mov boxBottom, ax
    call TestBoxAgainstObstacles

CheckCollisionDone:
    pop ax
    ret
CheckCollision ENDP

; tests the box in boxLeft..boxBottom against every obstacle, sets hitFlag on overlap
TestBoxAgainstObstacles PROC
    push ax
    push bx
    push di
    push si

    xor si, si
TestObstacleLoop:
    cmp obsKind[si], OBS_NONE
    je TestObstacleNext

    mov bl, obsKind[si]
    xor bh, bh
    shl bx, 1
    mov di, si
    shl di, 1

    ; the obstacle box is a little smaller than its picture
    mov ax, obsX[di]
    add ax, HIT_MARGIN_X
    cmp boxRight, ax
    jl TestObstacleNext

    mov ax, obsX[di]
    add ax, kindWidth[bx]
    sub ax, HIT_MARGIN_X+1
    cmp boxLeft, ax
    jg TestObstacleNext

    mov ax, kindTop[bx]
    add ax, HIT_MARGIN_Y
    cmp boxBottom, ax
    jl TestObstacleNext

    mov ax, kindTop[bx]
    add ax, kindHeight[bx]
    sub ax, HIT_MARGIN_Y+1
    cmp boxTop, ax
    jg TestObstacleNext

    mov hitFlag, 1
    jmp TestObstacleDone

TestObstacleNext:
    inc si
    cmp si, OBSTACLE_SLOTS
    jb TestObstacleLoop

TestObstacleDone:
    pop si
    pop di
    pop bx
    pop ax
    ret
TestBoxAgainstObstacles ENDP

; draws the whole scene in the back buffer
DrawScene PROC
    call CopyBackground
    call DrawClouds
    call DrawGroundMarks
    call DrawObstacles
    call DrawDinosaur
    ret
DrawScene ENDP

; draws the menu screen
DrawMenuScreen PROC
    call DrawScene
    call DrawMenuPanel
    call PresentFrame
    ret
DrawMenuScreen ENDP

; draws the screen while playing
DrawRunningScreen PROC
    call DrawScene
    call DrawRunningHUD
    call PresentFrame
    ret
DrawRunningScreen ENDP

; draws the pause screen
DrawPauseScreen PROC
    call DrawScene
    call DrawScoreHUD
    call DrawPausePanel
    call PresentFrame
    ret
DrawPauseScreen ENDP

; draws the game over screen
DrawGameOverScreen PROC
    call DrawScene
    call DrawScoreHUD
    call DrawGameOverPanel
    call PresentFrame
    ret
DrawGameOverScreen ENDP

; draws the sun into the background
DrawSun PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, COLOR_YELLOW
    mov ax, 248
    mov bx, 25
    mov cx, 22
    mov dx, 22
    call DrawRectangleFromRegisters

    mov ax, 244
    mov bx, 29
    mov cx, 30
    mov dx, 14
    call DrawRectangleFromRegisters

    mov ax, 252
    mov bx, 21
    mov cx, 14
    mov dx, 30
    call DrawRectangleFromRegisters

    mov rectColor, COLOR_WHITE
    mov ax, 252
    mov bx, 25
    mov cx, 10
    mov dx, 2
    call DrawRectangleFromRegisters

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawSun ENDP

; draws all clouds
DrawClouds PROC
    push cx
    push si
    xor si, si
    mov cx, CLOUD_COUNT
DrawCloudsLoop:
    call DrawCloud
    add si, 2
    loop DrawCloudsLoop
    pop si
    pop cx
    ret
DrawClouds ENDP

; draws one cloud, SI = cloud index times two
DrawCloud PROC
    push ax
    push bx
    push cx
    push dx
    push si

    mov ax, cloudX[si]
    mov cloudBaseX, ax
    mov ax, cloudY[si]
    mov cloudBaseY, ax
    mov rectColor, COLOR_WHITE

    mov ax, cloudBaseX
    mov bx, cloudBaseY
    add bx, 4
    mov cx, 25
    mov dx, 5
    call DrawRectangleFromRegisters

    mov ax, cloudBaseX
    add ax, 4
    mov bx, cloudBaseY
    mov cx, 8
    mov dx, 6
    call DrawRectangleFromRegisters

    mov ax, cloudBaseX
    add ax, 11
    mov bx, cloudBaseY
    sub bx, 2
    mov cx, 10
    mov dx, 8
    call DrawRectangleFromRegisters

    mov ax, cloudBaseX
    add ax, 19
    mov bx, cloudBaseY
    mov cx, 7
    mov dx, 6
    call DrawRectangleFromRegisters

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawCloud ENDP

; draws the hills in the distance
DrawFarHills PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, COLOR_GREEN
    mov ax, 0
    mov bx, 116
    mov cx, SCREEN_W
    mov dx, 48
    call DrawRectangleFromRegisters

    mov rectColor, COLOR_LIGHT_GREEN
    mov ax, 12
    mov bx, 105
    mov cx, 42
    mov dx, 12
    call DrawRectangleFromRegisters
    mov ax, 21
    mov bx, 98
    mov cx, 25
    mov dx, 8
    call DrawRectangleFromRegisters
    mov ax, 29
    mov bx, 92
    mov cx, 12
    mov dx, 7
    call DrawRectangleFromRegisters

    mov rectColor, COLOR_GREEN
    mov ax, 112
    mov bx, 108
    mov cx, 54
    mov dx, 18
    call DrawRectangleFromRegisters
    mov ax, 124
    mov bx, 99
    mov cx, 34
    mov dx, 10
    call DrawRectangleFromRegisters
    mov ax, 135
    mov bx, 93
    mov cx, 16
    mov dx, 7
    call DrawRectangleFromRegisters

    mov rectColor, COLOR_LIGHT_GREEN
    mov ax, 218
    mov bx, 111
    mov cx, 46
    mov dx, 15
    call DrawRectangleFromRegisters
    mov ax, 229
    mov bx, 103
    mov cx, 28
    mov dx, 9
    call DrawRectangleFromRegisters
    mov ax, 237
    mov bx, 96
    mov cx, 13
    mov dx, 8
    call DrawRectangleFromRegisters

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawFarHills ENDP

; draws the hills close to the ground
DrawNearHills PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, COLOR_GREEN
    mov ax, 0
    mov bx, 137
    mov cx, 320
    mov dx, 27
    call DrawRectangleFromRegisters

    mov rectColor, COLOR_LIGHT_GREEN
    mov ax, 0
    mov bx, 132
    mov cx, 40
    mov dx, 10
    call DrawRectangleFromRegisters
    mov ax, 22
    mov bx, 126
    mov cx, 27
    mov dx, 8
    call DrawRectangleFromRegisters
    mov ax, 44
    mov bx, 132
    mov cx, 34
    mov dx, 7
    call DrawRectangleFromRegisters

    mov rectColor, COLOR_GREEN
    mov ax, 165
    mov bx, 130
    mov cx, 49
    mov dx, 10
    call DrawRectangleFromRegisters
    mov ax, 188
    mov bx, 123
    mov cx, 29
    mov dx, 9
    call DrawRectangleFromRegisters
    mov ax, 209
    mov bx, 131
    mov cx, 43
    mov dx, 8
    call DrawRectangleFromRegisters

    mov rectColor, COLOR_LIGHT_GREEN
    mov ax, 265
    mov bx, 135
    mov cx, 55
    mov dx, 9
    call DrawRectangleFromRegisters
    mov ax, 279
    mov bx, 129
    mov cx, 28
    mov dx, 8
    call DrawRectangleFromRegisters

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawNearHills ENDP

; the parts of the ground that never move, drawn once into the cached background
DrawGroundBase PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, COLOR_BROWN
    mov ax, 0
    mov bx, GROUND_Y
    mov cx, SCREEN_W
    mov dx, SCREEN_H-GROUND_Y
    call DrawRectangleFromRegisters

    mov rectColor, COLOR_WHITE
    mov ax, 0
    mov bx, GROUND_Y
    mov cx, SCREEN_W
    mov dx, GROUND_LINE_H
    call DrawRectangleFromRegisters

    call DrawGroundPebbles

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawGroundBase ENDP

; draws the scrolling marks on the ground
DrawGroundMarks PROC
    push ax
    push bx
    push cx
    push dx

    mov dashIndex, 0
    mov rectColor, COLOR_LIGHT_GRAY

DrawGroundMarksLoop:
    ; a mark may start left of the screen, the rectangle clipper handles it
    mov ax, dashIndex
    mov bx, GROUND_MARK_GAP
    mul bx
    sub ax, groundOffset
    mov bx, GROUND_MARK_Y
    mov cx, GROUND_MARK_W
    mov dx, GROUND_MARK_H
    call DrawRectangleFromRegisters

    inc dashIndex
    cmp dashIndex, GROUND_MARK_COUNT
    jb DrawGroundMarksLoop

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawGroundMarks ENDP

; draws the small pebbles on the ground
DrawGroundPebbles PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, COLOR_DARK_GRAY

    mov ax, 18
    mov bx, 181
    mov cx, 3
    mov dx, 2
    call DrawRectangleFromRegisters

    mov ax, 73
    mov bx, 190
    mov cx, 4
    mov dx, 2
    call DrawRectangleFromRegisters

    mov ax, 129
    mov bx, 176
    mov cx, 3
    mov dx, 2
    call DrawRectangleFromRegisters

    mov ax, 189
    mov bx, 186
    mov cx, 5
    mov dx, 2
    call DrawRectangleFromRegisters

    mov ax, 258
    mov bx, 178
    mov cx, 3
    mov dx, 2
    call DrawRectangleFromRegisters

    mov ax, 302
    mov bx, 193
    mov cx, 4
    mov dx, 2
    call DrawRectangleFromRegisters

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawGroundPebbles ENDP

; AX = x, BX = y relative to the dinosaur's standing position
DrawDinoPart PROC
    sub bx, jumpHeight
    call DrawRectangleFromRegisters
    ret
DrawDinoPart ENDP

; draws the whole dinosaur from its parts
DrawDinosaur PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, DINO_BODY_COLOR
    call DrawDinoTail
    call DrawDinoBody
    call DrawDinoNeck
    call DrawDinoHead
    call DrawDinoSpikes
    call DrawDinoLegs
    call DrawDinoFace

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinosaur ENDP

DrawDinoTail PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, DINO_BODY_COLOR
    mov ax, DINO_X-8
    mov bx, 143
    mov cx, 10
    mov dx, 4
    call DrawDinoPart

    mov ax, DINO_X-11
    mov bx, 145
    mov cx, 5
    mov dx, 3
    call DrawDinoPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinoTail ENDP

DrawDinoBody PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, DINO_BODY_COLOR
    mov ax, DINO_X
    mov bx, 136
    mov cx, 25
    mov dx, 17
    call DrawDinoPart

    mov ax, DINO_X+4
    mov bx, 150
    mov cx, 17
    mov dx, 5
    call DrawDinoPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinoBody ENDP

DrawDinoNeck PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, DINO_BODY_COLOR
    mov ax, DINO_X+16
    mov bx, 129
    mov cx, 10
    mov dx, 15
    call DrawDinoPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinoNeck ENDP

DrawDinoHead PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, DINO_BODY_COLOR
    mov ax, DINO_X+20
    mov bx, 125
    mov cx, 18
    mov dx, 15
    call DrawDinoPart

    mov ax, DINO_X+32
    mov bx, 132
    mov cx, 10
    mov dx, 7
    call DrawDinoPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinoHead ENDP

DrawDinoSpikes PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, DINO_BODY_COLOR

    mov ax, DINO_X+3
    mov bx, 131
    mov cx, 5
    mov dx, 6
    call DrawDinoPart

    mov ax, DINO_X+9
    mov bx, 128
    mov cx, 5
    mov dx, 8
    call DrawDinoPart

    mov ax, DINO_X+15
    mov bx, 129
    mov cx, 4
    mov dx, 6
    call DrawDinoPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinoSpikes ENDP

; draws the eye and mouth, the eye is an X in the game over state
DrawDinoFace PROC
    push ax
    push bx
    push cx
    push dx

    cmp gameState, GAME_OVER
    je DrawDinoDeadEye

    mov rectColor, DINO_DETAIL_COLOR
    mov ax, DINO_X+31
    mov bx, 129
    mov cx, 2
    mov dx, 2
    call DrawDinoPart
    jmp DrawDinoMouth

DrawDinoDeadEye:
    mov rectColor, DINO_DETAIL_COLOR
    mov cx, 1
    mov dx, 1

    mov ax, DINO_X+30
    mov bx, 128
    call DrawDinoPart
    mov ax, DINO_X+31
    mov bx, 129
    call DrawDinoPart
    mov ax, DINO_X+32
    mov bx, 130
    call DrawDinoPart
    mov ax, DINO_X+33
    mov bx, 131
    call DrawDinoPart
    mov ax, DINO_X+33
    mov bx, 128
    call DrawDinoPart
    mov ax, DINO_X+32
    mov bx, 129
    call DrawDinoPart
    mov ax, DINO_X+31
    mov bx, 130
    call DrawDinoPart
    mov ax, DINO_X+30
    mov bx, 131
    call DrawDinoPart

DrawDinoMouth:
    mov rectColor, DINO_DETAIL_COLOR
    mov ax, DINO_X+37
    mov bx, 138
    mov cx, 3
    mov dx, 1
    call DrawDinoPart

    mov rectColor, COLOR_WHITE
    mov ax, DINO_X+30
    mov bx, 132
    mov cx, 2
    mov dx, 1
    call DrawDinoPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinoFace ENDP

; picks the leg pose that matches the current run frame
DrawDinoLegs PROC
    cmp runFrame, 0
    je SelectDinoLegFrame0
    cmp runFrame, 1
    je SelectDinoLegFrame1
    cmp runFrame, 2
    je SelectDinoLegFrame2
    jmp SelectDinoLegFrame3

SelectDinoLegFrame0:
    call DrawDinoLegFrame0
    ret
SelectDinoLegFrame1:
    call DrawDinoLegFrame1
    ret
SelectDinoLegFrame2:
    call DrawDinoLegFrame2
    ret
SelectDinoLegFrame3:
    call DrawDinoLegFrame3
    ret
DrawDinoLegs ENDP

DrawDinoLegFrame0 PROC
    push ax
    push bx
    push cx
    push dx
    mov rectColor, DINO_BODY_COLOR

    mov ax, DINO_X+4
    mov bx, 151
    mov cx, 5
    mov dx, 10
    call DrawDinoPart

    mov ax, DINO_X+2
    mov bx, 159
    mov cx, 9
    mov dx, 3
    call DrawDinoPart

    mov ax, DINO_X+17
    mov bx, 151
    mov cx, 5
    mov dx, 7
    call DrawDinoPart

    mov ax, DINO_X+17
    mov bx, 156
    mov cx, 8
    mov dx, 3
    call DrawDinoPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinoLegFrame0 ENDP

DrawDinoLegFrame1 PROC
    push ax
    push bx
    push cx
    push dx
    mov rectColor, DINO_BODY_COLOR

    mov ax, DINO_X+4
    mov bx, 151
    mov cx, 5
    mov dx, 6
    call DrawDinoPart

    mov ax, DINO_X+1
    mov bx, 155
    mov cx, 8
    mov dx, 3
    call DrawDinoPart

    mov ax, DINO_X+17
    mov bx, 151
    mov cx, 5
    mov dx, 12
    call DrawDinoPart

    mov ax, DINO_X+14
    mov bx, 160
    mov cx, 10
    mov dx, 3
    call DrawDinoPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinoLegFrame1 ENDP

DrawDinoLegFrame2 PROC
    push ax
    push bx
    push cx
    push dx
    mov rectColor, DINO_BODY_COLOR

    mov ax, DINO_X+4
    mov bx, 151
    mov cx, 5
    mov dx, 7
    call DrawDinoPart

    mov ax, DINO_X+1
    mov bx, 156
    mov cx, 8
    mov dx, 3
    call DrawDinoPart

    mov ax, DINO_X+17
    mov bx, 151
    mov cx, 5
    mov dx, 10
    call DrawDinoPart

    mov ax, DINO_X+14
    mov bx, 159
    mov cx, 10
    mov dx, 3
    call DrawDinoPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinoLegFrame2 ENDP

DrawDinoLegFrame3 PROC
    push ax
    push bx
    push cx
    push dx
    mov rectColor, DINO_BODY_COLOR

    mov ax, DINO_X+4
    mov bx, 151
    mov cx, 5
    mov dx, 12
    call DrawDinoPart

    mov ax, DINO_X+1
    mov bx, 160
    mov cx, 9
    mov dx, 3
    call DrawDinoPart

    mov ax, DINO_X+17
    mov bx, 151
    mov cx, 5
    mov dx, 6
    call DrawDinoPart

    mov ax, DINO_X+17
    mov bx, 155
    mov cx, 8
    mov dx, 3
    call DrawDinoPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDinoLegFrame3 ENDP

; AX = x offset, BX = y offset inside the current obstacle (objX, objY)
DrawObjectPart PROC
    add ax, objX
    add bx, objY
    call DrawRectangleFromRegisters
    ret
DrawObjectPart ENDP

; draws every active obstacle
DrawObstacles PROC
    push ax
    push bx
    push cx
    push di
    push si

    xor si, si
DrawObstacleLoop:
    cmp obsKind[si], OBS_NONE
    je DrawObstacleNext

    mov cl, obsKind[si]
    mov bl, cl
    xor bh, bh
    shl bx, 1
    mov ax, kindTop[bx]
    mov objY, ax
    mov di, si
    shl di, 1
    mov ax, obsX[di]
    mov objX, ax

    cmp cl, 1
    je DrawObstacleTall
    cmp cl, 2
    je DrawObstacleDouble
    cmp cl, 3
    je DrawObstacleTriple
    cmp cl, 4
    jae DrawObstacleBird

    call DrawCactusSmall
    jmp DrawObstacleNext

DrawObstacleTall:
    call DrawCactusTall
    jmp DrawObstacleNext

DrawObstacleDouble:
    call DrawCactusSmall
    add objX, 14
    call DrawCactusSmall
    jmp DrawObstacleNext

DrawObstacleTriple:
    call DrawCactusSmall
    add objX, 14
    call DrawCactusSmall
    add objX, 14
    call DrawCactusSmall
    jmp DrawObstacleNext

DrawObstacleBird:
    call DrawBird

DrawObstacleNext:
    inc si
    cmp si, OBSTACLE_SLOTS
    jb DrawObstacleLoop

    pop si
    pop di
    pop cx
    pop bx
    pop ax
    ret
DrawObstacles ENDP

; draws one small cactus at (objX, objY)
DrawCactusSmall PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, COLOR_DARK_GRAY

    mov ax, 4
    mov bx, 0
    mov cx, 4
    mov dx, 22
    call DrawObjectPart

    mov ax, 0
    mov bx, 9
    mov cx, 5
    mov dx, 3
    call DrawObjectPart

    mov ax, 0
    mov bx, 4
    mov cx, 3
    mov dx, 8
    call DrawObjectPart

    mov ax, 7
    mov bx, 12
    mov cx, 4
    mov dx, 3
    call DrawObjectPart

    mov ax, 8
    mov bx, 7
    mov cx, 3
    mov dx, 8
    call DrawObjectPart

    mov rectColor, COLOR_LIGHT_GRAY
    mov ax, 5
    mov bx, 1
    mov cx, 1
    mov dx, 20
    call DrawObjectPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawCactusSmall ENDP

; draws one tall cactus at (objX, objY)
DrawCactusTall PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, COLOR_DARK_GRAY

    mov ax, 5
    mov bx, 0
    mov cx, 5
    mov dx, 32
    call DrawObjectPart

    mov ax, 0
    mov bx, 14
    mov cx, 6
    mov dx, 3
    call DrawObjectPart

    mov ax, 0
    mov bx, 8
    mov cx, 3
    mov dx, 9
    call DrawObjectPart

    mov ax, 9
    mov bx, 18
    mov cx, 6
    mov dx, 3
    call DrawObjectPart

    mov ax, 12
    mov bx, 11
    mov cx, 3
    mov dx, 10
    call DrawObjectPart

    mov rectColor, COLOR_LIGHT_GRAY
    mov ax, 6
    mov bx, 1
    mov cx, 1
    mov dx, 30
    call DrawObjectPart

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawCactusTall ENDP

; draws one bird at (objX, objY), the wings depend on birdFrame
DrawBird PROC
    push ax
    push bx
    push cx
    push dx

    ; body, head, beak and tail
    mov rectColor, COLOR_DARK_GRAY
    mov ax, 4
    mov bx, 5
    mov cx, 14
    mov dx, 5
    call DrawObjectPart

    mov ax, 2
    mov bx, 4
    mov cx, 5
    mov dx, 5
    call DrawObjectPart

    mov ax, 17
    mov bx, 7
    mov cx, 4
    mov dx, 3
    call DrawObjectPart

    mov rectColor, COLOR_YELLOW
    mov ax, 0
    mov bx, 6
    mov cx, 3
    mov dx, 2
    call DrawObjectPart

    mov rectColor, COLOR_WHITE
    mov ax, 3
    mov bx, 5
    mov cx, 1
    mov dx, 1
    call DrawObjectPart

    ; wings, two flap positions
    mov rectColor, COLOR_DARK_GRAY
    cmp birdFrame, 0
    jne DrawBirdWingsDown

    mov ax, 8
    mov bx, 0
    mov cx, 4
    mov dx, 6
    call DrawObjectPart
    mov ax, 11
    mov bx, 1
    mov cx, 4
    mov dx, 5
    call DrawObjectPart
    jmp DrawBirdDone

DrawBirdWingsDown:
    mov ax, 8
    mov bx, 10
    mov cx, 4
    mov dx, 4
    call DrawObjectPart
    mov ax, 11
    mov bx, 10
    mov cx, 4
    mov dx, 3
    call DrawObjectPart

DrawBirdDone:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawBird ENDP

; draws the text and border of the main menu
DrawMenuPanel PROC
    push ax
    push bx
    push cx
    push dx

    call DrawMenuBorder

    mov dh, 4
    mov dl, 17
    call SetCursor
    mov textColor, COLOR_WHITE
    mov si, OFFSET titleText
    call PrintString

    mov dh, 9
    mov dl, 11
    call SetCursor
    mov textColor, COLOR_YELLOW
    mov si, OFFSET menuJumpText
    call PrintString

    mov dh, 12
    mov dl, 10
    call SetCursor
    mov textColor, COLOR_WHITE
    mov si, OFFSET startText
    call PrintString

    mov dh, 15
    mov dl, 15
    call SetCursor
    mov textColor, COLOR_LIGHT_CYAN
    mov si, OFFSET menuQuitText
    call PrintString

    mov dh, 18
    mov dl, 13
    call SetCursor
    mov textColor, COLOR_LIGHT_GREEN
    mov si, OFFSET menuFooterText
    call PrintString

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawMenuPanel ENDP

; draws the frame around the menu
DrawMenuBorder PROC
    push ax
    push bx
    push cx
    push dx

    mov rectColor, COLOR_LIGHT_CYAN
    mov ax, 64
    mov bx, 54
    mov cx, 192
    mov dx, 2
    call DrawRectangleFromRegisters

    mov ax, 64
    mov bx, 54
    mov cx, 2
    mov dx, 104
    call DrawRectangleFromRegisters

    mov ax, 64
    mov bx, 156
    mov cx, 192
    mov dx, 2
    call DrawRectangleFromRegisters

    mov ax, 254
    mov bx, 54
    mov cx, 2
    mov dx, 104
    call DrawRectangleFromRegisters

    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawMenuBorder ENDP

; prints the best score and the current score
DrawScoreHUD PROC
    push ax
    push dx
    push si

    mov dh, 1
    mov dl, 21
    call SetCursor
    mov textColor, COLOR_WHITE
    mov si, OFFSET hiText
    call PrintString
    mov ax, bestScore
    call PrintNumber5
    mov si, OFFSET spaceText
    call PrintString
    mov ax, score
    call PrintNumber5

    pop si
    pop dx
    pop ax
    ret
DrawScoreHUD ENDP

; prints the texts shown while playing
DrawRunningHUD PROC
    push ax
    push dx
    push si

    mov dh, 1
    mov dl, 2
    call SetCursor
    mov textColor, COLOR_WHITE
    mov si, OFFSET titleText
    call PrintString

    mov dh, 3
    mov dl, 2
    call SetCursor
    mov textColor, COLOR_YELLOW
    mov si, OFFSET runningPauseText
    call PrintString

    mov dh, 5
    mov dl, 2
    call SetCursor
    mov si, OFFSET runningMenuText
    call PrintString

    call DrawScoreHUD

    pop si
    pop dx
    pop ax
    ret
DrawRunningHUD ENDP

; draws the box and text of the pause screen
DrawPausePanel PROC
    push ax
    push bx
    push cx
    push dx
    push si

    mov rectColor, COLOR_BLUE
    mov ax, 76
    mov bx, 40
    mov cx, 168
    mov dx, 50
    call DrawRectangleFromRegisters

    mov rectColor, COLOR_YELLOW
    mov ax, 76
    mov bx, 40
    mov cx, 168
    mov dx, 2
    call DrawRectangleFromRegisters

    mov ax, 76
    mov bx, 88
    mov cx, 168
    mov dx, 2
    call DrawRectangleFromRegisters

    mov dh, 7
    mov dl, 17
    call SetCursor
    mov textColor, COLOR_YELLOW
    mov si, OFFSET pausedTitle
    call PrintString

    mov dh, 9
    mov dl, 10
    call SetCursor
    mov textColor, COLOR_WHITE
    mov si, OFFSET pausedResumeText
    call PrintString

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawPausePanel ENDP

; draws the box and text of the game over screen
DrawGameOverPanel PROC
    push ax
    push bx
    push cx
    push dx
    push si

    mov rectColor, COLOR_BLUE
    mov ax, 76
    mov bx, 24
    mov cx, 168
    mov dx, 84
    call DrawRectangleFromRegisters

    mov rectColor, COLOR_YELLOW
    mov ax, 76
    mov bx, 24
    mov cx, 168
    mov dx, 2
    call DrawRectangleFromRegisters

    mov ax, 76
    mov bx, 106
    mov cx, 168
    mov dx, 2
    call DrawRectangleFromRegisters

    mov dh, 4
    mov dl, 15
    call SetCursor
    mov textColor, COLOR_YELLOW
    mov si, OFFSET gameOverTitle
    call PrintString

    mov dh, 6
    mov dl, 14
    call SetCursor
    mov textColor, COLOR_WHITE
    mov si, OFFSET gameOverScoreText
    call PrintString
    mov ax, score
    call PrintNumber5

    cmp newBestFlag, 0
    je DrawGameOverButtons
    mov dh, 8
    mov dl, 15
    call SetCursor
    mov textColor, COLOR_LIGHT_GREEN
    mov si, OFFSET newBestText
    call PrintString

DrawGameOverButtons:
    mov dh, 10
    mov dl, 12
    call SetCursor
    mov textColor, COLOR_WHITE
    mov si, OFFSET gameOverRetryText
    call PrintString

    mov dh, 12
    mov dl, 15
    call SetCursor
    mov textColor, COLOR_LIGHT_CYAN
    mov si, OFFSET gameOverQuitText
    call PrintString

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawGameOverPanel ENDP

; DH = row, DL = column (8x8 character cells, 40 x 25 in mode 13h)
SetCursor PROC
    push ax
    push cx
    mov cl, 3
    mov al, dl
    xor ah, ah
    shl ax, cl
    mov textX, ax
    mov al, dh
    xor ah, ah
    shl ax, cl
    mov textY, ax
    pop cx
    pop ax
    ret
SetCursor ENDP

; prints the zero ended string at DS:SI
PrintString PROC
    push ax
    push si
    cld
PrintStringNext:
    lodsb
    cmp al, 0
    je PrintStringDone
    call PutChar
    jmp PrintStringNext
PrintStringDone:
    pop si
    pop ax
    ret
PrintString ENDP

; prints AX as exactly five digits with leading zeros
PrintNumber5 PROC
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, OFFSET digitDivisors
    mov cx, 5
PrintNumberDigit:
    mov bx, [si]
    xor dx, dx
    div bx
    push dx
    add al, '0'
    call PutChar
    pop ax
    add si, 2
    loop PrintNumberDigit

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PrintNumber5 ENDP

; draws the character in AL at (textX, textY) with a shadow, then moves right
PutChar PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    ; copy the 8 glyph rows out of the ROM font
    xor ah, ah
    mov cl, 3
    shl ax, cl
    add ax, fontOff
    mov si, ax
    mov ax, @data
    mov es, ax
    mov di, OFFSET glyphBuf
    mov ax, fontSeg
    mov ds, ax
    mov cx, 8
    cld
    rep movsb
    mov ax, es
    mov ds, ax

    mov ax, textY
    mov cx, SCREEN_W
    mul cx
    add ax, textX
    mov di, ax
    mov ax, drawSeg
    mov es, ax

    push di
    add di, SCREEN_W+1
    mov bl, COLOR_BLACK
    call DrawGlyphBits
    pop di
    mov bl, textColor
    call DrawGlyphBits

    add textX, 8

    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PutChar ENDP

; draws glyphBuf at ES:DI in color BL, bit 7 of each row is the left pixel
DrawGlyphBits PROC
    push ax
    push cx
    push dx
    push di
    push si

    mov si, OFFSET glyphBuf
    mov dx, 8
GlyphRow:
    mov al, [si]
    inc si
    mov cx, 8
    push di
GlyphPixel:
    shl al, 1
    jnc GlyphSkip
    mov es:[di], bl
GlyphSkip:
    inc di
    loop GlyphPixel
    pop di
    add di, SCREEN_W
    dec dx
    jnz GlyphRow

    pop si
    pop di
    pop dx
    pop cx
    pop ax
    ret
DrawGlyphBits ENDP

; fills the whole draw buffer with fillColor
FillScreen PROC
    push ax
    push cx
    push di
    push es

    mov ax, drawSeg
    mov es, ax
    xor di, di
    mov al, fillColor
    mov ah, al
    mov cx, SCREEN_WORDS
    cld
    rep stosw

    pop es
    pop di
    pop cx
    pop ax
    ret
FillScreen ENDP

; AX = x, BX = y, CX = width, DX = height, color in rectColor
DrawRectangleFromRegisters PROC
    mov rectX, ax
    mov rectY, bx
    mov rectW, cx
    mov rectH, dx
    call DrawRectangle
    ret
DrawRectangleFromRegisters ENDP

; draws a filled rectangle and clips it to the screen
DrawRectangle PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    cmp rectW, 0
    je DrawRectangleDone
    cmp rectH, 0
    je DrawRectangleDone

    ; clip the part that sticks out on the left side
    mov ax, rectX
    test ax, 8000h
    jz DrawRectangleLeftReady
    add ax, rectW
    jle DrawRectangleDone
    mov rectW, ax
    mov rectX, 0

DrawRectangleLeftReady:
    mov ax, rectX
    cmp ax, SCREEN_W
    jae DrawRectangleDone
    mov ax, rectY
    cmp ax, SCREEN_H
    jae DrawRectangleDone

    ; clip the right and bottom edges
    mov ax, SCREEN_W
    sub ax, rectX
    cmp rectW, ax
    jbe DrawRectangleWidthReady
    mov rectW, ax
DrawRectangleWidthReady:
    mov ax, SCREEN_H
    sub ax, rectY
    cmp rectH, ax
    jbe DrawRectangleHeightReady
    mov rectH, ax
DrawRectangleHeightReady:

    mov ax, drawSeg
    mov es, ax
    cld

    ; offset = Y * 320 + X
    mov ax, rectY
    mov bx, SCREEN_W
    mul bx
    add ax, rectX
    mov di, ax
    mov si, rectH

DrawRectangleRow:
    mov cx, rectW
    mov al, rectColor
    rep stosb

    ; jump to the same column on the next row
    mov ax, SCREEN_W
    sub ax, rectW
    add di, ax

    dec si
    jnz DrawRectangleRow

DrawRectangleDone:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawRectangle ENDP

END start