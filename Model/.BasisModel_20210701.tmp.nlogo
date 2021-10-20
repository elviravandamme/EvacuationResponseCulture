; 25/05
; All visitors do have a sitting place, however they are not all at their place in the beginning of the simulation
; Simple response-activities added

; 26/05
; pack-belongings-other-location-action is working, but takes long time to calculate path
; Now turtles still walk over purple tables etc. If they are not allowed to do this, system takes too much time to calculate astar

; 28/05
; Friend links + find friends is working
; Sometimes turtles turn around each other and take long time to find each other

; 31/05
; Basic list of response actions is working
; Visitors can follow the actions within a list

; 02/06
; Fire-fight procedure
;Merge test and non-test
; Finding friends not working

; 04/05
; Fixed probleem dat alle turtles taken van andere turtles uitvoeren --> ask turtles in functie weggehaald

;28/06
; Find-friend-other location --> lijkt nog niet perfect te lopen

__includes [ "utilities.nls" "astaralgorithm.nls" "Setup.nls" "Response_activities.nls" ] ;; all the boring but important stuff not related to content
extensions [time]

;;;;;;;;;;;;;;;;;;;;;;;; VARIABLES ;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  all-colors
  exit-north1                  ;; Exit on top (left one of the two doors)
  exit-north2                  ;; Exit on top (right one of the two doors)
  exit-west                    ;; Exit on left
  exit-east                    ;; Exit on right
  main-exit                    ;; The exit chosen as main exit in a specific model version
  exit-possibilities           ;; The exits available in a specific model version
  astar_closed                 ;; The closed list of patches --> see astaralgorithm.nls
  astar_open                   ;; The open list of patches --> see astaralgorithm.nls
  obstacles                    ;; Patches that an agent can not walk on (e.g. walls, fire, outside building)
  date-time                    ;; Current date and time
  tick-datetime                ;; Connects 1 tick to 1 second
  Alarm                        ;; Alarm goes off
  start-alarm                  ;; The moment at which danger happens and the alarm goes off
  alarm-happened?              ;; Check if alarm has gone off already
  stop-condition?              ;; Check if model should be stopped
  total-evacuation-time        ;; The total evacuation time until all turtles have left the building
]

breed [ staff a-staff ]
breed [ visitors visitor ]

turtles-own [
  man?                         ;; Man/ Female property. If man? is set to true, the turtle is a man, otherwise it is a woman.
  normal-state?                ;; No awareness of incident
  notification-state?          ;;
  response-state?              ;; Will change to true when turtle is responding to threat; executing information and action tasks
  evacuating-state?            ;; Will change to true when a turtle stands up from its place and starts evacuating
  evacuated-state?             ;; Set to true when a turtle hasa left the building and thus is evacuated
  walking-speed                ;;
  task-time-left               ;; Amount of time left to finish a non-evacuation task
  nearby-visitors              ;; Agent set of nearby visitors
  familiarity?                 ;; Familiarity property. If familiarity? is set to true, a turtle is familiar with the building.
  current-destination          ;; The patch the agent is currently going towards.
  path                         ;; The optimal path from source to destination --> see astaralgorithm.nls
  current-path                 ;; Part of the path that is left to be traversed --> see astaralgorithm.nls
  exit-destination             ;; The destination/ exit that a turtle goes to to leave the building.
  response-time                ;; The time from the moment the alarm goes off, until a turtle decides to leave its' place.
  evacuation-time              ;; The time it takes a turtle to leave the building, after the alarm has gone of ( thus includes response time).
  fire-seen?                   ;; Set to true if the turtle has actually seen the fire happening
  response-countoff            ;; Random countoff for the time that a turtle needs to respond, after being informed or aware of fire.
  informed-danger?             ;; Set to true if the turtle has been informed of the danger. Meaning that the turtle informing this turtle has also seen the fire or has been informed about it.
  wait-informing-visitors-nearby? ;; Set to true if there are any visitors close to the turtle, for which the turtle needs to wait before he evacuates himself
  sitting-place                ;; Initial place where person is sitting
  path-sitting-place           ;; Sitting place of a visitor
  friends                      ;; List of friends of a visitor
  response-tasks-list          ;; Total list of response tasks to be executed
  current-response-tasks-list  ;; List of response tasks which still need to be executed
  current-response-task        ;; Response tasks which is currently being executed
  response-activity-time-left  ;;
  response-task-finished-check?;;
  task-only-run-once?          ;; Check if task is only setting a time or also executing something
  notification-time               ;; Total notification time
  notification-time-countoff      ;; notification time left
  first-response-task?          ;; Check if the first task has been done or not
  all-response-tasks-finished?
  friend
  number-of-places-to-visit
  first-time-destination-nearby?
  scan-environment-counter
  number-of-places-visited
  looking-around-seek-info?
]

staff-own[
]

visitors-own [
  fire-trained?               ;; Set to true if the visitor has had a fire-training before. This does  not necessarily mean that visitor is familiar with building
]

patches-own [
  fire?                       ;; Set to true if there is fire taking place on a patch
  parent-patch                ;; patch's predecessor --> see astaralgorithm.nls
  f                           ;; the value of knowledge plus heuristic cost function f() --> see astaralgorithm.nls
  g                           ;; the value of knowledge cost function g() --> see astaralgorithm.nls
  h                           ;; the value of heuristic cost function h() --> see astaralgorithm.nls
]

;;;;;;;;;;;;;;;; GO-PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to go
  if stop-condition? = true                                                               ;; End of simulation condition
  [stop]

  ;;; Start fire and alarm ;;;
  if ( Alarm = True or (start-alarm = 3000 and ticks = 30) and alarm-happened? = false )  ;; Alarm goes off and fire happens if button is pushed or if ticks = 30
    [set start-alarm ticks                                                                ;; Set time that alarm goes off
      set alarm-happened? true
      fire                                                                                ;; Puts patch on fire
      ask staff [ set task-time-left 0  set notification-time-countoff random 12 ]                 ;; Staff immediately stops task when alarm goes off. They start evacuating within 12 seconds
      ask visitors [ if( fire-trained? = true ) [  set notification-time-countoff random 12 ] ]    ;; Fire-trained visitors respond within 12 seconds after alarm goes off
      set Alarm false]

 if (ticks = (start-alarm + 2 ) )[
   spread-fire ]                                                                          ;; Fire spreads vigorously 2 seconds after first fire takes place

  if ticks = 70 [
    spread-fire]                                                                           ;; Fire spreads more vigorously

  ;;; Normal state  + notification state;;;
  ask turtles [
    if ( normal-state? = true ) [
      start-task                                                                          ;; Turtle can start a new task at any point in time
      set task-time-left task-time-left - 1                                               ;; Every tick, task-time-left decreases by 1, as the time passes
      check-neighbours-evacuating                                                         ;; Turtle checks if he sees others nearby evacuate
      if task-time-left <= 0[
        normal-state-walk ]

      if ticks = 70 and notification-time-countoff > 100 [
        set notification-time-countoff random 100 ] ]];; If people are not evacuating yet, they will start evacuating within 100 seconds

    ask turtles [
    if ( normal-state? = true ) [
      if ( notification-time-countoff <= 0 and normal-state? = true ) [ ;; Turtle starts evacuating if he is not yet evacuating and his response-countoff has achieved 0
        set normal-state? false
        set response-state? true
        set color pink
        setup-visitor-tasks]
      if  any? patches with [pcolor = orange ] in-radius vision-distance and notification-time-countoff > 4
      [set fire-seen? true set notification-time-countoff random 4 ];; If turtle is close to fire, starts evacuating within 4 seconds
      set notification-time-countoff notification-time-countoff - 1] ]                                       ;; Every tick, notification-time-countoff decreases by 1, as the time passes]


  ;; Response state ;;;
ask visitors [
    if response-state? = true [
      if task-only-run-once? = false
      [ run current-response-task ]                                          ;; Keep executing task until finished

      if response-activity-time-left = 0 or response-task-finished-check? = true ;; START NEW TASK either check if the time is finished or the task has been finished
      [ set task-only-run-once? false
        if first-response-task? = false[
          set current-response-tasks-list but-first current-response-tasks-list]  ;; Removes first item of the list
        ifelse length current-response-tasks-list > 0 [                              ;; Check if there are still tasks to be finished
          set current-response-task item 0 current-response-tasks-list
          set  response-task-finished-check? false
          run current-response-task
          set first-response-task? false]                                          ;; Sets new task as current-tasks
        [set response-state? false
          set current-response-task []
          set evacuating-state? true
          set color green
          set all-response-tasks-finished? true
          start-evacuating]                                                      ;; When done; start evacuating
      ]
      set response-activity-time-left response-activity-time-left - 1]]           ;; Every tick decrease response activity time

  ;; Evacuation state ;;;
  ask staff  [ if evacuating-state? = true [ if staff-informing-others? = true                                          ;; Switch so that if not desired, staff will not inform others
    [  inform-neighbor-visitors  ]]]        ;; Staff informs others to start evacuating
  ;ask visitors
  ;[ if( ( fire-trained? = true or fire-seen? = true or informed-danger? = true ) and (evacuating-state? = true) ) ;; Fire-trained visitors or visitors who have seen fire or are informed about it,  will inform other visitors
  ;  [ inform-neighbor-visitors ]]
  ask turtles [if wait-informing-visitors-nearby? = false and evacuating-state? = true [                                          ;; A turtle is only moving, when he is not waiting for others nearby to evacuate ( this is actually only a thing for staff )
    move ]]

  ;; Anytime
  ask turtles [ if evacuated-state? = false [
    if [pcolor] of patch-here = orange or [pcolor] of patch-here = yellow [               ;; Resolves error, which keeps turtles trapped inside fire
      fd 4 set path 99999 ]]
  ]

;;;  Analysis ;;;
  if ( count ( turtles with [ evacuated-state? = true ] ) = ( initial-number-visitor + initial-number-staff ) or ticks > 2000 ) [
    set stop-condition? true                                                              ;; Model should stop after all turtles are evacuated
    set total-evacuation-time ticks - start-alarm
    output-print ( word "The total evacuation time is: " total-evacuation-time )
    output-print ( word " ")
    output-print ( word "The average response time of all people is: " mean [ response-time ] of turtles )
    output-print ( word "The average response time of visitors is: " mean [ response-time ] of visitors   )
   ; output-print ( word "The average response time of staff is: " mean [ response-time ] of staff)
    output-print ( word " ")
    output-print (word "The average evacuation time of all people is: " mean [evacuation-time ] of turtles )
    output-print (word "The average evacuation time of visitors is: " mean [evacuation-time ] of visitors )
    ;output-print (word "The average evacuation time of staff is: " mean [evacuation-time ] of staff )
    ]

  tick                                                                                    ;; next time step

end

to execute_response_task
  ifelse current-response-task = "phone-seek-info" [ phone-seek-info ][
    ifelse  current-response-task = "Electronic-media-seek-info" [Electronic-media-seek-info] [
      ifelse  current-response-task = "seek-info-coversation" [seek-info-coversation][
        ifelse  current-response-task = "phone-share-info" [phone-share-info][
          ifelse current-response-task = "shut-down-work-action" [ shut-down-work-action][
            ifelse current-response-task = "take-coat-action" [take-coat-action][
              ifelse current-response-task = "pack-belongings-nearby-action" [pack-belongings-nearby-action][
                ifelse current-response-task = "pack-belongings-nearby-action" [pack-belongings-nearby-action][
                  ifelse current-response-task = "change-footwear-clothes-action" [change-footwear-clothes-action][
                    ifelse current-response-task = "secure-office-action" [secure-office-action][
                      ifelse current-response-task = "call-alarm-number-action" [ call-alarm-number-action] [
                        ifelse current-response-task = "pack-belongings-other-location-action" [pack-belongings-other-location-action][
                          ifelse current-response-task = "find-friend-other-location" [ find-friend-other-location][
                            if current-response-task = "fight-fire" [fight-fire]]]]]]]]]]]]]]
end



;;;;;;;;;;;;;;; Standard Non-evacuation procedures;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to start-task
  if ( evacuating-state? = false  and random 100 < 3 )                                          ;; 2 Percent of the turtles start a new task at any specific point in time
    [ set task-time-left random 50 ]                                                      ;; Random time length of a task
end

to move                                                                                   ;; Procedure which makes the turtles move
  if [pcolor] of patch-here = orange [                                                    ;; Resolves error, which keeps turtles trapped inside fire
      fd 2 set path 99999 ]

  if [pcolor] of patch-here = 14.8 and evacuating-state? = true  [                              ;; If the turtles are on the exit, then they will be considered to be evacuated and they will hide
    let check-if-destination-nearby patches in-radius 10
    if member? exit-destination check-if-destination-nearby [                                  ;; Checks if the correct destination is within a radius of 10
      set evacuated-state? true
      set evacuating-state? false
      set evacuation-time ticks - start-alarm
      hide-turtle]
  ]
  if evacuating-state? = true and [pcolor] of patch-here != 14.8
  [ if  path = 99999 or [pcolor] of patch-ahead 1 = orange  [     ;; Only if the turtle has not calculated a shortest path yet, or there are other turtles in front, or it is nearby-fire, it will calculate a new path
      set current-destination exit-destination                                                 ;; If turtle is evacauting, current-destination to "destination", which is the chosen exit
      set path find-a-path patch-here current-destination                                 ;; Astar determines shortest path
      set current-path path ]
    move-along-path                                                                      ;; Make turtle move to the destination via the path found
  ]
                                                                 ;; let the agent avoid obstacles while randomly walking
end

to normal-state-walk
  if patch-here = current-destination                                                   ;; Turtle is not evacuating. If turtle is already at the current-destination, look for a new current-destination
    [set current-destination one-of patches with [pcolor = 9.9]                           ;; Setting the new current-destination to a random white patch
      face current-destination ]
  if random 100 < 80 and task-time-left = 0 [                                            ;; If a person is not doing a task and not evacuating, there is a 70% of him walking                                                                     ;; Turtles avoid obstacles when moving randomly
    face current-destination                                                                ;; Turtle faces the current destination it wants to go to
    let visible-patches patches in-cone vision-distance vision-angle                       ;;Check if we have a obstancle nearby. if yes, how far is it, if it is too close, then turn
    let obstacles-here visible-patches with [pcolor = black  or pcolor = orange or pcolor = yellow or pcolor = red or pcolor = 14.8 or pcolor = 44.9 or pcolor = 126]
    if any? obstacles-here
    [if distance-nearest-obstacle obstacles-here < 4 * walking-speed
      [ rt random 90 + 180                                                                  ;; If there is an obstacle, then execute a random turn
    ]]
    if  [ pcolor = white ] of patch-ahead 1 [                                               ;; Only move forward if the next patch in front is white
      fd ( walking-speed / 1.5 ) ]]                                                          ;; Turtle moves forward with current speed
end

to-report distance-nearest-obstacle [obstacles-here]                                      ;; Reports distance of nearest-obstacle
  let nearest-distance 9999
  ask obstacles-here [
    let distance-to-x distance myself
    if distance-to-x  < nearest-distance [set nearest-distance distance-to-x ]
  ]
  report nearest-distance
end


;;;;;;;;;;;;;;;; FIRE-PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to fire                                                                                   ;; This procedure starts the fire
  ask one-of patches with [ pcolor = white and pycor < 141 and pxcor > 40 and not any? turtles-here ]               ;; Fire can only occur on white patches, so the fire doesn't show up outside on the stairs in front of the library. It can also not occur too close to an exit
  [ set fire? true
    set pcolor orange
    ask neighbors [set pcolor orange set fire? true]                                      ;; Make neighboring patches orange as well
  ]
end

to spread-fire                                                                            ;;  Spreading fire procedure, as the time ticks.
   ask patches with [ pcolor = orange ] [
   ask neighbors4 with [pcolor = white or pcolor = yellow or pcolor = black] [            ;; Yellow zone is considered danger zone, but not the fire itself. This makes sure turtles
    ;  not on patches very close to fire itself
    set pcolor orange set fire? true
      ask neighbors4 with [ pcolor = white or pcolor = black or pcolor = yellow]  [ set pcolor yellow set fire? true
        ask neighbors4 with [ pcolor = white or pcolor = black or pcolor = yellow]  [ set pcolor yellow set fire? true ] ]
    ]]
end
;;;;;;;;;;;;;;;; EVACUATION-PROCEDURES ;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to check-neighbours-evacuating                                                            ;; Check if there are more than 7 neighbours in-sight evacuating
  if evacuating-state? = false and evacuated-state? = false and notification-time-countoff > 12 [
    let neighbours-evacuating count other turtles in-cone vision-distance vision-angle with [ evacuating-state? = true ]
    if neighbours-evacuating > 7 [  set notification-time-countoff random 12 ] ]                   ;; If there are many neighbors evacuating, turtle starts evacuating in 7 seconds
end

to start-evacuating
  set evacuating-state? true                                                                    ;; A turtle starts evacuating
  set response-state? false
  set response-time ticks - start-alarm
  set task-time-left 0
  set current-destination exit-destination
  if exit-destination = 99999  [ choose-exit ]                                                ;; Only if turtles don't already have a destination, they will choose one
  set current-destination exit-destination                                                 ;; If turtle is evacauting, current-destination to "destination", which is the chosen exit
  set path find-a-path patch-here current-destination                                 ;; Astar determines shortest path
  set current-path path
end

to choose-exit                                                                            ;; Choose the exit that a turtles uses to leave the building
  ifelse familiarity? = false
  [set exit-destination one-of main-exit]                                                      ;; If a turtle is not familiar with the building he wil choose the main exit
  [    let check-nearest-destination ( min-one-of exit-possibilities [distance myself ] )
    set exit-destination check-nearest-destination ]                                           ;; Familiar turtles check which exit is nearby
end

to move-along-path                                                                        ;; Turtle follows his path
  let starting-patch patch-here
  face first current-path
  let others-nearby count other turtles in-cone 2 80 with [ evacuated-state? = false ]          ;; Checks how many turtles are nearby, adjust walking-speed based on amount of turtles nearby.
  ifelse others-nearby <= 2                                                               ;;  If there is a maximum of 2 turtles nearby, speed does not change
  [  fd ( walking-speed / 1.5 ) ]
  [ifelse  others-nearby <= 4                                                             ;; If others-evacuating nearby is bigger than 2, but <= than 4. Speed decreases by 0.2
    [ fd ( ( walking-speed - 0.2 ) / 1.5 ) ]
    [ifelse others-nearby <= 8                                                            ;; If others-evacuating nearby is bigger than 4, but <= than 8. Speed decreases by 0.7
      [ fd ( ( walking-speed - 0.7 ) / 1.5 ) ]
       [ifelse others-nearby <= 10                                                        ;; If others-evacuating nearby is bigger than 8, but <= 10. Speed becomes 0.3
        [ fd  ( 0.3 / 1.5 ) ]
        [if others-nearby > 10                                                            ;; If others-evacating nearby > 10. Speed becomes 0.1
          [fd ( 0.1 / 1.5 ) ] ] ] ] ]

  ifelse  patch-here = first current-path [
    set current-path remove-item 0 current-path]                                         ;; Adjusts the path accordingly to where turtle is
  [ if length current-path > 1 [if patch-here = item 1 current-path [  set current-path remove-item 0 current-path set current-path remove-item 0 current-path ]]]

end

;;;;;;;;;;;;;;;; INFORMING PROCEDURES ;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to inform-neighbor-visitors                                                               ;; Inform nearby visitors and they will start evacuating
  set nearby-visitors other visitors in-radius vision-distance                            ;; Check which visitors are nearby
  if any? nearby-visitors
  [
    ask nearby-visitors                                                                   ;; check if there are visitors nearby, if this is true and they are not already evacuating, these visitors will start evecuating within 5 seconds
    [ if evacuating-state? = false and evacuated-state? = false and notification-time-countoff > 5 [set notification-time-countoff random 5] ]

    if (informed-danger? = true or fire-seen? = true)                                     ;; If someone is informed about the danger or has seen the danger, they ask the visitors they meet to set-informed-danger true.
    [ask nearby-visitors                                                                  ;;In this case they will also inform other about the danger that has been seen.
      [ if (evacuating-state? = false and evacuated-state? = false)
        [set informed-danger? true] ]

    if breed = staff                                                                      ;; Staff members will point all turtles which he sees on the way to the nearest destination
    [ let staff-destination exit-destination
        ask nearby-visitors [if exit-destination != staff-destination [
          set exit-destination staff-destination                                               ;; The informed turtle will go to the same exit as the staff who informed him/her
          set path 99999                                                                  ;; The visitors need to determine a new path for their new destination. Thus their path is set to 99999, so that they will choose a new path during next tick
      ]] ]
  ]]
  if breed = staff [                                                                      ;; Staff waits for other nearby visitors to start evacuating, before they start moving themselves
  let nearby-visitors-not-evacuating other visitors in-radius vision-distance with [ evacuating-state? = false and evacuated-state? = false ]  ;; checking if there are nearby-visitors not evacuating
    ifelse any? nearby-visitors-not-evacuating [ set wait-informing-visitors-nearby? true ] [ set wait-informing-visitors-nearby? false ] ]
end





;;; test;;;;

to test
  if stop-condition? = true                                                               ;; End of simulation condition
  [stop]
if ticks = 1
  [fire]

  if ticks > 1[
  ask visitors [
    if response-state? = true [
      if response-activity-time-left != 0 and task-only-run-once? = false
      [ run first current-response-tasks-list ]                                          ;; Keep executing task until finished

      if response-activity-time-left = 0 or response-task-finished-check? = true ;; START NEW TASK Either check if the time is finished or the task has been finished
      [  set task-only-run-once? false
        set current-response-tasks-list but-first  current-response-tasks-list  ;; Removes first item of the list
        ifelse length current-response-tasks-list > 0 [                              ;; Check if there are still tasks to be finished
          set current-response-task item 0 current-response-tasks-list
          set  response-task-finished-check? false
          run first current-response-tasks-list]                                          ;; Sets new task as current-tasks
        [set response-state? false
          start-evacuating]                                                      ;; When done; start evacuating
      ]
      set response-activity-time-left response-activity-time-left - 1]]           ;; Every tick decrease response activity time
  ]
  tick
  if ticks > 3000  [set stop-condition? true ]

end
@#$#@#$#@
GRAPHICS-WINDOW
835
11
1434
642
-1
-1
2.321
1
10
1
1
1
0
0
0
1
0
254
0
267
1
1
1
ticks
30.0

BUTTON
632
30
705
63
NIL
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
633
66
696
99
NIL
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

SWITCH
611
168
732
201
verbose?
verbose?
0
1
-1000

SWITCH
620
215
730
248
debug?
debug?
0
1
-1000

SLIDER
7
10
179
43
initial-number-visitor
initial-number-visitor
0
200
10.0
1
1
NIL
HORIZONTAL

SLIDER
8
46
180
79
initial-number-staff
initial-number-staff
0
200
0.0
1
1
NIL
HORIZONTAL

MONITOR
149
571
254
616
Visitors evacuating
count visitors with [ evacuating-state? = True ]
17
1
11

SLIDER
7
84
238
117
gender-ratio
gender-ratio
0
100
44.0
2
1
% men of whole population
HORIZONTAL

SLIDER
9
120
295
153
adult-ratio
adult-ratio
0
100
100.0
2
1
% of adults in visitor population
HORIZONTAL

BUTTON
708
67
785
100
go-once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
181
10
360
43
vision-distance
vision-distance
0
15
6.0
1
1
patches
HORIZONTAL

SLIDER
181
46
353
79
vision-angle
vision-angle
0
180
55.0
5
1
NIL
HORIZONTAL

SLIDER
8
158
266
191
Familiarity-meter
Familiarity-meter
0
100
66.0
2
1
% of visitors familiar
HORIZONTAL

MONITOR
38
522
202
567
Total # of people inside building
count turtles with [ evacuated-state? = false ]
17
1
11

MONITOR
38
570
143
615
Staff evacuating
count staff with [ evacuating-state? =  True ]
17
1
11

MONITOR
38
620
139
665
Agents evacuated
count turtles with [ evacuated-state? =  True ]
1
1
11

PLOT
257
260
834
507
Number of agents evacuated over time
Time
# Evacuated
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Total" 1.0 0 -16777216 true "" "plot count turtles with [ evacuated-state? =  True ]"
"Staff" 1.0 0 -13345367 true "" "plot count staff with [ evacuated-state? =  True ]"
"visitors" 1.0 0 -10899396 true "" "plot count visitors with [ evacuated-state? =  True ]"

CHOOSER
377
70
631
115
Exits-available
Exits-available
"All-exits" "Only-North-exit" "North-West" "North-East" "West-East" "West-only" "East-only"
1

SWITCH
424
217
609
250
Staff-informing-others?
Staff-informing-others?
1
1
-1000

MONITOR
36
672
283
717
Date (year/month/day) Time (hrs/min/sec)
tick-datetime
17
1
11

BUTTON
717
27
780
60
Alarm
set Alarm true
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

OUTPUT
286
507
814
665
11

SLIDER
8
196
274
229
Visitors-not-on-place
Visitors-not-on-place
0
50
6.0
1
1
% of visitors not on place
HORIZONTAL

BUTTON
756
120
819
153
test
test
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
8
269
245
302
chance-friends-nearby
chance-friends-nearby
0
100
86.0
1
1
NIL
HORIZONTAL

SLIDER
8
232
202
265
Chance-friends-in-building
Chance-friends-in-building
0
100
75.0
1
1
NIL
HORIZONTAL

BUTTON
647
120
736
153
NIL
test-setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
745
170
830
203
test-once
test
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
8
309
201
342
Chance-waiting-for-friend
Chance-waiting-for-friend
0
100
53.0
1
1
NIL
HORIZONTAL

SLIDER
6
348
235
381
chance-find-personal-belongings
chance-find-personal-belongings
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
8
386
180
419
chance-find-friend
chance-find-friend
0
100
50.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

The model is showing the evacuation of the Library in TU delft. A distinction has been made between two kinds of people within the model: staff and visitors. Staff are working in the library and are familiar with the building and with how to handle when a fire breaks out. Visitors can be students or other members of the general public within the library, this group of people can include children as well. 
Based in different input parameters, it can be analysed which variables have most influence on evacuation times and how a change in these parameter values will cause different results. 

## HOW IT WORKS

Either at 30 ticks, or when the alarm button is pushed, a fire will start as well as the fire alarm. 
Staff members will start evacuation immediately. For visitors it can take some time to realise that they need to evacuate. They can realise this by themselves, or they can be informed to evacuated by staff members or other visitors. 

Based on their familiarity and the exits available, agents will decide trough which exit they will evacuate. 

The model stops automatically when all people have left the library. At this point in time, the toal evacuation time will be calculated. 

Behaviour of the agents consists of: 
- Walking randomly or performing a task when they are not evacuating
- Choosing the exit trough which they will evacuated, based on their familiarity
- Moving towards the chosen exit. The path taken will be calculated with the Aster algorithm. Obstacles and fire are avoided on their ways to the exits
- Staff members willl inform visitors on the evacuation and the nearest exits
- Fire-trained visitors and visitors who have seen the fire,  will inform visitors to start evacuating
- Visitors will start evacuating whenever they see more than 7 people leave at the same moment in time
- Visitors can be part of a group, with which they will stay together during the evacuation.


## HOW TO USE IT

The model can be started and if the alarm button has not been clicked, the fire and fire alarm start after 30 seconds. When the alarm button it clicked, the fire and alarm will start immediately.

There are many input parameters that can be decided on by the model user:
- Inital number of staff present within the building
- Inital number of visitors present within the building
- Gender- ratio: the percentage of the population that is men
- Adult-ratio: the percentage of the population that is an adult
- Familiarity-meter: the percentage of the population that is familiar with the building
- Vision-distance in patches: How many patches ahead an agent can look. One patch equals 1.5 meter
- Vision-angle: the angle widt of an agents vision
- Exits available: the availability of exits while running the model
- Staff-informing-others? If this is set to true, staff members will inform other visitors about the evacuation on their way out. If it is set to false, they won't.
- Groups?  If this is set to true, there will be 2 groups formed within the model. The turtles part of a group will be coloured purple and red.
- max-group1-size: The groupsize of the first group
- max-group2-size:  The groupsize of the second group

A graph is shown with the interface, which provides real-time information during the run. 
The output box shows information on the evacuation, when the run has ended.


## THINGS TO NOTICE

It is interesting to see how turtles influence each other. 
For example how staff waits for visitors in its surroundings to start evacuating. Or how walking speeds of agents is dependent upon the amount of other agents in their surroundings. 
Lastly one can look at how agents are informed about the evacuation. And about how this information spreads trough the crowd.

## THINGS TO TRY

It is suggested for the user to play with all the input parameters described above, to see the effects that these have on the simulation.

## EXTENDING THE MODEL

It would be suggested for further research to include some of the following elements in the model: 
-  Realistic spreading of the fire and development of smoke within the building.
- Casualties due to fire. 
- Movements within the environments. For example furniture moving around and parts of the building collapsing.
- Static or dynamic signs in the building.
- All the floor levels of the library. Only the floor level has been taken for research.
- Behavioural aspects: the effect of emotions, cultural differences and behaviour of different demographic groups.
- People falling, helping each other, getting stuck and losing consciousness.
- Walking speed being influenced by the kind of surface that people are walking on. For example stairs or slippery floors
-  Disabilities of people within the library. Everyone is considered as having a good mobility.


## RELATED MODELS

There are no models in the Netlogo library, which show evacuation behaviour. There are many models available online on evacuation behaviour, none of these is focussed on the TU  Delft library. 

## CREDITS AND REFERENCES
Model developed by Elvira Van Damme, Syed Mujtaba Fardeen and Francien Baijanova.
The Astar algorithm file, utilities file and library map have been provided by the TU Delft. These have been adjusted to fit the model.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person service
false
0
Polygon -7500403 true true 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -1 true false 120 90 105 90 60 195 90 210 120 150 120 195 180 195 180 150 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Polygon -1 true false 123 90 149 141 177 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Rectangle -16777216 true false 179 164 183 186
Polygon -2674135 true false 180 90 195 90 183 160 180 195 150 195 150 135 180 90
Polygon -2674135 true false 120 90 105 90 114 161 120 195 150 195 150 135 120 90
Polygon -2674135 true false 155 91 128 77 128 101
Rectangle -16777216 true false 118 129 141 140
Polygon -2674135 true false 145 91 172 77 172 101

person student
false
0
Polygon -13791810 true false 135 90 150 105 135 165 150 180 165 165 150 105 165 90
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 100 210 130 225 145 165 85 135 63 189
Polygon -13791810 true false 90 210 120 225 135 165 67 130 53 189
Polygon -1 true false 120 224 131 225 124 210
Line -16777216 false 139 168 126 225
Line -16777216 false 140 167 76 136
Polygon -7500403 true true 105 90 60 195 90 210 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Basecase1run" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors with [ evacuating? = true or evacuated? = true ]</metric>
    <metric>[ response-time ] of staff with [ evacuating? = true or evacuated? = true ]</metric>
    <metric>[evacuation-time] of visitors with [evacuated? = true ]</metric>
    <metric>[evacuation-time] of staff with [evacuated? = true ]</metric>
    <metric>count staff with [ evacuating? = true]</metric>
    <metric>count visitors with [ evacuating? = true]</metric>
    <metric>count staff with [ evacuated? =  True ]</metric>
    <metric>count visitors with [ evacuated? =  True ]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Groups?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Staff-informing-others?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="55"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-group2-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-group1-size">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-ratio">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
