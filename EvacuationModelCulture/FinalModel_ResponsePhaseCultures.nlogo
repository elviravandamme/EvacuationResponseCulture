__includes [ "utilities.nls" "astaralgorithm.nls" "Setup.nls" "Response_activities.nls" "Response_activities_adjust.nls" "Response_activities_setup.nls"  ] ;; all the boring but important stuff not related to content
extensions [time profiler]



;;;;;;;;;;;;;;;; GO-PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to go

  ;; End of simulation condition
  if stop-condition? = true
  [stop]
  if timer > 900 [set stop-condition? true ]

  ;; Define walking patches
  if ticks = 1
  [
    set walking-patches patches with [ (pcolor != black) and (pcolor != orange) and (pcolor != 44.9) and (pcolor != 44.8) and (pcolor != 42.6) and (pcolor != yellow)]
    set free-patches patches with [member? self walking-patches and (count (turtles-here with [evacuated-state? = false]) < 6 )] ]

  ;; Define available visitors
  set available-visitors-set visitors with [ evacuating-state? = false and evacuated-state? = false]

  ;; Start fire and alarm
  if ( Alarm = True or (start-alarm = 3000 and ticks = 30) and alarm-happened? = false )  ;; Alarm goes off and fire happens if button is pushed or if ticks = 30
    [set start-alarm ticks                                                                ;; Set time that alarm goes off
      set alarm-happened? true
      fire                                                                                ;; Puts patch on fire
      ask staff [ set task-time-left 0  set notification-time-countoff 3 + random 8 ]     ;; Staff immediately stops task when alarm goes off. They start evacuating within 12 seconds
      ask visitors [set notification-time-countoff 6 + random 90 ]
      set Alarm false]

  if (ticks = (start-alarm + 2 ) )[
    spread-fire ]                                                                         ;; Fire spreads vigorously 2 seconds after first fire takes place                                                                     ;; Fire spreads more vigorously

  ;; States of agents: Normal, response, evacuating
  ask turtles [
    ifelse ( normal-state? = true ) [all-turtles-normal-state]
    [ if evacuating-state? = true [all-turtles-evacuating-state]  ]]

  ask visitors [
    if response-state? = true   [visitors-response-state]]

  ask staff [
      if response-state? = true [staff-response-state]]


  ;; Anytime: Avoid fire
  ask turtles [ if evacuated-state? = false [
    while [([pcolor] of patch-here = orange) or ([pcolor] of patch-here = yellow) ] [   ;; Resolves error, which keeps turtles trapped inside fire
      face min-one-of patches with [pcolor = 9.9] [distance myself]
      fd 1 set path 99999 ]
  ]]

  ;;  Analysis
  if ( count ( turtles with [ evacuated-state? = true ] ) = ( initial-number-visitor + initial-number-staff ) or ticks > 2000 ) [
    final-analysis
  ]

  ;; Faster model timer: These timers make sure that some procedures are only performed once every few ticks
  set faster-model-timer1 faster-model-timer1 + 1
  set faster-model-timer2 faster-model-timer2 + 1
  set faster-model-timer3 faster-model-timer3  + 1

  ifelse (ticks mod 4 = 0) [ set faster-model-timer1 0
    if (ticks mod 8 = 0)[
      set free-patches walking-patches with [ (count (turtles-here) < 6 )]
  ]]
  [if ( (ticks + 1) mod 4 = 0)
    [set faster-model-timer2 0]
   if ( (ticks + 2) mod 4 = 0)
    [set faster-model-timer3 0]]



  tick                                                                                    ;; next time step

end

;;;;;;;;;;;;;;;; AGENT STATES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to all-turtles-normal-state
  if task-time-left <= 0 [
    normal-state-walk
    start-task]                                                                       ;; Turtle can start a new task at any point in time
  set task-time-left task-time-left - 1                                               ;; Every tick, task-time-left decreases by 1, as the time passes
  check-neighbours-evacuating                                                         ;; Turtle checks if he sees others nearby evacuate

  if faster-model-timer2 = 0 and  any? patches with [pcolor = orange ] in-cone vision-distance vision-angle
  [set fire-seen? true
    if notification-time-countoff > 4 [
      set notification-time-countoff random 4 ]]                                      ;; If turtle is close to fire, starts evacuating within 4 seconds

  set notification-time-countoff notification-time-countoff - 1

  if  notification-time-countoff <= 0 [                                               ;; Turtle starts evacuating if he is not yet evacuating and his response-countoff has achieved 0
    set normal-state? false
    set response-state? true
    set notification-time ticks - start-alarm
    if breed = visitors [                                                             ;; Setup visitor response tasks
      set color pink
      setup-visitor-tasks]
    if breed = staff
    [setup-staff-tasks]]                                                              ;; Setup staff response tasks

end

to visitors-response-state

  ifelse  conversationing-time-left <= 0[                                             ;; Only if an agent is not conversationing with others, he will perform his own response tasks
    if conversationing-with-staff? = true
    [set conversationing-with-staff? false]


    if faster-model-timer1 = 0 and fire-seen? = false and ( any? patches with [pcolor = orange ] in-cone vision-distance vision-angle)
    [set fire-seen? true
      fire-seen-adjust-response-tasks]                                                ;; Adjust response tasks after seeing fire

    if task-only-run-once? = false
    [ run current-response-task ]                                                     ;; Keep executing task until finished

    if (response-activity-time-left = 0 or response-task-finished-check? = true) and response-state? = true ;; Start new task either check if the time is finished or the task has been finished
    [ set task-only-run-once? false
      ifelse first-response-task? = false[
        set current-response-tasks-list but-first current-response-tasks-list        ;; Remove finished task from currentt-response-tasks-list
        set conversation-buddy 0
        set path 99999]  ;; Removes first item of the list
      [set first-response-task? false
        set conversation-buddy 0
        set path 99999]
      ifelse length current-response-tasks-list > 0 [                                ;; Check if there are still tasks to be finished
        set current-response-task item 0 current-response-tasks-list
        set  response-task-finished-check? false
        set  response-activity-time-left 1000
        run current-response-task

        ;; Finalising response tasks
        if length current-response-tasks-list = 1 and current-response-task != "wait-for-friend" and current-response-task != "find-friend-other-location" and
        current-response-task != "find-and-wait-for-friend-check" and current-response-task !=  "pack-belongings-other-location-action"
        [ collect-belongings-check
          if any? friends
          [set current-response-tasks-list lput "find-and-wait-for-friend-check" current-response-tasks-list set task-only-run-once?  false]
      ]]
      [set response-state? false                                                    ;; If all response tasks are finished, start evacuating
        set current-response-task []
        set evacuating-state? true
        set color green
        set all-response-tasks-finished? true
        start-evacuating]
    ]
    set response-activity-time-left response-activity-time-left - 1]                ;; Response activity time left decreases while performing tasks

  [set conversationing-time-left conversationing-time-left - 1]
end

to staff-response-state

  ifelse  (conversationing-time-left <= 0)[                                         ;; Only if an agent is not conversationing with others, he will perform his own response tasks

    if task-only-run-once? = false
    [ run current-response-task ]                                                   ;; Keep executing task until finished

    if (response-activity-time-left = 0 or response-task-finished-check? = true)    ;; Start new task either if the time is finished or the task has been finished
    [ set task-only-run-once? false
      ifelse first-response-task? = false [
        set current-response-tasks-list but-first current-response-tasks-list       ;; Removes first item of the list
        set conversation-buddy 0
        set path 99999]
      [set first-response-task? false
        set conversation-buddy 0
        set path 99999]
      ifelse length current-response-tasks-list > 0 [                               ;; Check if there are still tasks to be finished
        set current-response-task item 0 current-response-tasks-list                ;; Sets new task as current-task
        set  response-task-finished-check? false
        run current-response-task
        set first-response-task? false
        set looking-around-seek-info? false
      ]
      [set response-state? false
        set current-response-task []
        set evacuating-state? true
        set all-response-tasks-finished? true
        start-evacuating]                                                            ;; When done; start evacuating
    ]
    set response-activity-time-left response-activity-time-left - 1]
  [set conversationing-time-left conversationing-time-left - 1]
end

to all-turtles-evacuating-state

  ifelse  (conversationing-time-left <= 0)[                                          ;; A turtle is only moving, when he is not conversationing witht others
    ifelse breed = staff[
      let x people-informed
      ifelse (conversation-buddy != 0 or ( faster-model-timer3 = 0 and any? visitors in-cone vision-distance (vision-angle + 50) with [member? self available-visitors-set and
        not member? self x and (not member? self [buddy-walking-away] of myself )] )) ;; Staff informs others to start evacuating
      [inform-visitors-while-evacuating]
      [move]]
    [move]  ]
  [set conversationing-time-left conversationing-time-left - 1]
end

;;;;;;;;;;;;;;; FINAL ANALYSIS ;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to final-analysis

  set stop-condition? true                                                              ;; Model should stop after all turtles are evacuated
  set total-evacuation-time ticks - start-alarm
 ; profiler:stop          ;; stop profiling
 ; print profiler:report  ;; view the results
  output-print ( word "The total evacuation time is: " total-evacuation-time )
  output-print ( word " ")
  if initial-number-visitor != 0 [
    output-print ( word "The average response time of visitors is: " mean [ response-time ] of visitors   )
    if initial-number-staff != 0 [
      output-print ( word "The average response time of all people is: " mean [ response-time ] of turtles )]]
  if initial-number-staff != 0 [ output-print ( word "The average response time of staff is: " mean [ response-time ] of staff)]
  output-print ( word " ")
  output-print (word "The average evacuation time of all people is: " mean [evacuation-time ] of turtles )
  if initial-number-visitor != 0 [
    output-print (word "The average evacuation time of visitors is: " mean [evacuation-time ] of visitors )]
  if initial-number-staff != 0 [
    output-print (word "The average evacuation time of staff is: " mean [evacuation-time ] of staff )]
end


;;;;;;;;;;;;;;; STANDARD NON-EVACUATION PROCEDURES;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to start-task
  if ( evacuating-state? = false  and random 100 < 3 )                                    ;; 2 Percent of the turtles start a new task at any specific point in time
    [ set task-time-left 30 + random 50 ]                                                 ;; Random time length of a task
end

to normal-state-walk
  if patch-here = current-destination
    [set current-destination one-of patches with [member? self walking-patches]           ;; If turtle is already at the current-destination, look for a new current-destination
      face current-destination ]
  if random 100 < 20 and task-time-left <= 0 [                                            ;; If a person is not doing a task and not evacuating, there is a 70% of him walking                                                                     ;; Turtles avoid obstacles when moving randomly
    face current-destination                                                              ;; Turtle faces the current destination it wants to go to
    if not member? patch-ahead 1 walking-patches  [
     face  min-one-of walking-patches [distance myself]]
    fd ( walking-speed / patchsize ) ]                                                    ;; Turtle moves forward with current speed
end



;;;;;;;;;;;;;;;; FIRE-PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to fire                                                                                   ;; This procedure starts the fire
  ask one-of patches with [ pcolor = white and ((pycor < 127 and pycor > 14 and pxcor > 38 and pxcor < 130 ) )  and not any? turtles-here and distance min-one-of patches with [pcolor = 87.1][distance myself] > 4 and
    distance min-one-of patches with [pcolor = 118.1][distance myself] > 4 and distance min-one-of exit-possibilities [distance myself] > 10
    and distance (patch 108 85) > 7 and distance (patch 117 79) > 7 and distance (patch 126 27) > 7 and distance (patch 40 18) > 5
  ]                                                                                       ;; Fire can only occur on white patches. It can not occur too close to an exit
  [set fire? true
    set pcolor orange ]

  set walking-patches patches with [(pcolor != black) and (pcolor != orange) and (pcolor != 44.9)  and (pcolor != 44.8) and (pcolor != yellow)] ;; Re-define walking patches
  set free-patches  patches with [member? self walking-patches and (count (turtles-here with [evacuated-state? = false]) < 6 )] ;; Re-define free patches

end

to spread-fire                                                                            ;;  Spreading fire procedure, as the time ticks.
  ask patches with [ pcolor = orange ] [
    ask neighbors with [pcolor = white or pcolor = yellow or pcolor = black] [            ;; Yellow zone is considered danger zone, but not the fire itself.
      set pcolor orange set fire? true
      ask neighbors with [ pcolor = white or pcolor = black or pcolor = yellow]  [ set pcolor yellow set fire? true]
  ]]
  ask patches with [pcolor = orange]
  [ask neighbors with [pcolor = white] [set pcolor orange]]
  set walking-patches patches with [(pcolor != black) and (pcolor != orange) and (pcolor != 44.9)  and (pcolor != 44.8) and (pcolor != yellow) ]
  set free-patches  patches with [member? self walking-patches and (count (turtles-here with [evacuated-state? = false]) < 6 )]
end


;;;;;;;;;;;;;;;; EVACUATION-PROCEDURES ;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to check-neighbours-evacuating                                                             ;; Check if there are more than 7 neighbours in-sight evacuating
  if faster-model-timer1 = 0 and normal-state? = true [
    if notification-time-countoff > 8 [
      let neighbours-evacuating count other turtles in-cone vision-distance vision-angle with [evacuating-state? = true ]
      if neighbours-evacuating > 7 [
        set notification-time-countoff random 8 ] ] ]                                      ;; If there are many neighbors evacuating, adjust notification time
end

to start-evacuating
  set evacuating-state? true                                                               ;; A turtle starts evacuating
  set response-state? false
  set response-time (ticks - start-alarm)
  set response-time-excl-notif (ticks - notification-time)

  set task-time-left 0
  if (exit-destination = 99999 or (distance exit-destination > 20 and
    (distance (min-one-of exit-possibilities[distance myself]) < 20)))  [ choose-exit ]   ;; Only if agent doesn't already has a destination,or os far away from one, the agent will will choose one

  ;; Friends use the same exit
  if breed = visitors [
    if evacuating-with-friend? = true and [exit-destination] of friend != 99999
    [let exit-destination-set (patch-set exit-destination ([exit-destination] of friend))
      let closest-exit-destination min-one-of exit-destination-set [distance myself]     ;; compare distances to exit choices from agent itself and from friend
      ifelse closest-exit-destination = exit-destination
      [ask friend [                                                                      ;; Friend adjusts destination
        set exit-destination closest-exit-destination
        set current-destination exit-destination
        ifelse [path] of myself != []
        [set path [path] of myself
          set current-path path]
        [set path find-a-path patch-here current-destination
          set current-path path]]]
      [set exit-destination closest-exit-destination                                     ;; Agent adjusts destination
        set current-destination exit-destination
        ifelse [path] of friend != []
        [set path [path] of friend
          set current-path path]
        [ set path find-a-path patch-here current-destination
          set current-path path]]
  ]]

  if current-destination != exit-destination [
    set current-destination exit-destination
    set path find-a-path patch-here current-destination                                 ;; Finds shortest path towards exit
      set current-path path]

end


to choose-exit                                                                          ;; Choose the exit that agent uses to leave the building
  ifelse familiarity? = false
  [ ifelse count (exit-possibilities in-radius vision-distance) > 0
    [set exit-destination min-one-of exit-possibilities [distance myself ]]             ;; If agent can see an exit, he will go to this exit
    [set exit-destination one-of main-exit] ]                                           ;; If a agent is not familiar with the building he wil choose the main exit
  [set exit-destination min-one-of exit-possibilities [distance myself ] ]              ;; Familiar agents check which exit is nearby
end

to move

  if evacuating-state? = true [
    if  distance exit-destination <= 2 or ( (pcolor = [pcolor] of exit-destination) and (distance exit-destination < 15))  [
      move-to exit-destination                                                          ;; When evacuating and nearby exit, change to evacuated state
      set evacuated-state? true
      set evacuating-state? false
      set evacuation-time ticks - start-alarm
      set movement-time ticks - response-time
      hide-turtle]
  ]

  if [pcolor] of patch-here != 14.8
    [ if  path = 99999 or path = [] or current-path = []  [                             ;; If the turtle has not calculated a shortest path yet, or there are other turtles in front, or it is nearby-fire, it will calculate a new path
    while [[pcolor] of patch-here = 0] [face min-one-of patches with [member? self walking-patches][distance myself] fd 1]
    set current-destination exit-destination                                           ;; If turtle is evacauting, current-destination to "destination", which is the chosen exit
    set path find-a-path patch-here current-destination                                 ;; Astar determines shortest path
    set current-path path ]
    move-along-path                                                                     ;; Make turtle move to the destination via the path found
  ]
end

to move-along-path                                                                      ;; Turtle follows his path

  if faster-model-timer1 = 0 and evacuating-state? = true and distance exit-destination < 35 [
    if recaculated-path-ticks-time = 0 or ((ticks - recaculated-path-ticks-time) > 7) [
      let others-nearby2 count other turtles in-cone 3 vision-angle with [ evacuated-state? = false ] ;; If exit is nearby, and there is clogging in front, adjust recalculate path
      if others-nearby2 > 8 [
        let patch-to-left patch-left-and-ahead ( 40 + random 50) walking-speed
        ifelse (patch-to-left) != nobody and member? patch-to-left walking-patches
        [face patch-to-left fd walking-speed ]
        [let patch-to-right patch-right-and-ahead ( 40 + random 50) walking-speed
          if (patch-to-right) != nobody and member? patch-to-right walking-patches
          [face patch-to-right fd walking-speed ]
        ]
        if (random 100) < 50 [set exit-destination min-one-of exit-possibilities [distance myself ]
          set current-destination exit-destination]
        set path find-a-path patch-here current-destination
        set current-path path
        set recaculated-path-ticks-time ticks
        stop
  ]]]

  if current-path != 0 and not empty? current-path [                                          ;; Follow path and adjust speed
    let others-nearby count other turtles in-cone 2 vision-angle  with [ evacuated-state? = false ]
    face first current-path
    ifelse others-nearby < (2 )                                                               ;;  If there is a maximum of 2 turtles nearby, speed does not change
    [  fd ( walking-speed / patchsize ) ]
    [ifelse  others-nearby <=  ( 3 )                                                          ;; If others-evacuating nearby is bigger than 2, but <= than 4. Speed decreases by 0.2
      [ fd ( ( walking-speed - 0.6 ) / patchsize ) ]
      [ifelse others-nearby <= (5 )                                                           ;; If others-evacuating nearby is bigger than 4, but <= than 8. Speed decreases by 0.7
        [ fd ( 0.5 / patchsize ) ]
        [ifelse others-nearby <= ( 7 )                                                        ;; If others-evacuating nearby is bigger than 8, but <= 10. Speed becomes 0.3
          [ fd  ( 0.38 / patchsize ) ]
          [if others-nearby > (7)                                                             ;; If others-evacating nearby > 10. Speed becomes 0.1
            [fd ( random-float 0.1 / patchsize ) ] ] ] ] ]

    ifelse  patch-here = first current-path [
      set current-path remove-item 0 current-path]                                            ;; Adjusts the path accordingly to where turtle is
    [ if length current-path > 1 [if patch-here = item 1 current-path [  set current-path remove-item 0 current-path set current-path remove-item 0 current-path ]]]]

end


;;;;;;;;;;;;;;;; INFORMING PROCEDURES ;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to inform-visitors-while-evacuating                                                            ;; Inform nearby visitors and they will start evacuating
  let x people-informed
  let z walking-speed
  let u buddy-walking-away
  if conversation-buddy = 0 and any? visitors in-cone vision-distance vision-angle             ;; If staff member does not has conversation buddy, and he sees visitors nearby; choose one to inform
  [ifelse x != 0 and not empty? x [
    let nearby-visitors2 visitors in-cone vision-distance (vision-angle + 50) with [ not member? self x and conversationing-with-staff? = false and member? self available-visitors-set and
      ((last-time-conversationing-with-staff = 0) or((ticks - last-time-conversationing-with-staff) > 7))]
    if any? nearby-visitors2
    [set conversation-buddy min-one-of nearby-visitors2 [distance myself]                      ;; Choose closest visitor as conversation buddy
      set current-destination [patch-here] of conversation-buddy
      check-destination-properties]]
    [ let nearby-visitors3 visitors in-cone vision-distance (vision-angle + 50) with [ member? self available-visitors-set and conversationing-with-staff? = false and
      ((last-time-conversationing-with-staff = 0) or((ticks - last-time-conversationing-with-staff) > 7))]
      if any? nearby-visitors3
      [set conversation-buddy min-one-of nearby-visitors3 [distance myself]
        set current-destination [patch-here] of conversation-buddy
        check-destination-properties]
  ]]

  if conversation-buddy != 0 and conversation-buddy != nobody[

    if looking-around-seek-info? = false [
      ;; If conversation-buddy is walking away with higher speed, stop following buddy
      if faster-model-timer3 = 0 and ( (distance current-destination < 3 and distance conversation-buddy > 3) and walking-speed < ([walking-speed] of conversation-buddy))
      [set conversation-buddy 0
        set buddy-walking-away lput  conversation-buddy buddy-walking-away
        set path 99999
        stop]

      ; If conversation buddy is evacuated or if conversation-buddy is not on the same patch anymore or if someone else is close, choose new buddy
      if faster-model-timer3 = 0 and ( ([evacuated-state?] of conversation-buddy = true or [evacuating-state?] of conversation-buddy = true or [conversationing-with-staff?] of conversation-buddy = true) or
      (distance current-destination < 3 and distance conversation-buddy > 3 and (recaculated-path-ticks-time = 0 or ((ticks - recaculated-path-ticks-time)  >= 7)))
      or distance conversation-buddy > (vision-distance + 5))
      [ let possible-buddies (visitors in-cone vision-distance (vision-angle + 50) with [ not member? self x and  member? self available-visitors-set and  conversationing-with-staff? = false
        and (not member? self u ) ] )                                                         ;; Only select buddies who you have not talked to yet
        ifelse (count possible-buddies) > 0 [
          set conversation-buddy min-one-of possible-buddies [distance myself]
          set buddy-walking-away []
          set current-destination [patch-here] of conversation-buddy
          check-destination-properties
          if distance current-destination < 3 and distance conversation-buddy > 3
          [ set recaculated-path-ticks-time ticks]]
        [set conversation-buddy 0
          set path 99999
            stop ] ]


      ifelse distance current-destination > 2 [                                               ;; Determine path if there is no path. Move along path while not close to anyone
        if (path = 99999 or path = [] or current-path = []) and current-destination != 99999 [
          set path find-a-path patch-here current-destination
          set current-path path]
        move-along-path
      ]
      [
        if faster-model-timer3 = 0 and ( distance current-destination < 2 and distance conversation-buddy > 3)
        [set conversation-buddy 0
          set path 99999
          stop ]


        if distance conversation-buddy < 2 [                                                 ;; First time visitor is close to conversation buddy, start informing and inform others around
          let nearby-people-informing visitors in-radius 4 with [not member? self x and member? self available-visitors-set]
          set scan-environment-counter 3 + random 5
          let y scan-environment-counter
          set looking-around-seek-info? true
          ifelse count nearby-people-informing > 1 [

            let nearby-people-informing-list [self] of nearby-people-informing
            foreach nearby-people-informing-list [ person-informed ->
              set people-informed lput person-informed people-informed]
            ask nearby-people-informing                                                     ;; also inform other visitors around
            [ set conversationing-with-staff? true
              set conversationing-time-left y
              ifelse normal-state? = true
              [set informed-by-staff? true
                if notification-time-countoff > 5 [
                  set notification-time-countoff random 5]]
              [if response-state? = true
                [if informed-by-staff? = false [
                  set informed-by-staff? true
                  informed-by-staff-adjust-response-tasks
              ]]]
              set exit-destination min-one-of exit-possibilities [distance myself]]]


          [set people-informed lput conversation-buddy people-informed
            ask conversation-buddy
            [set conversationing-with-staff? true
              set conversationing-time-left y
              ifelse normal-state? = true
              [set informed-by-staff? true
                if notification-time-countoff > 5 [
                  set notification-time-countoff random 5]]
              [if response-state? = true
                [if informed-by-staff? = false [
                  set informed-by-staff? true
                  informed-by-staff-adjust-response-tasks]
              ]]
              set exit-destination min-one-of exit-possibilities [distance myself]]
    ]]]]

    If looking-around-seek-info? = true[
      ifelse scan-environment-counter > 0 [
        set scan-environment-counter scan-environment-counter - 1
        let xx people-informed
        let nearby-people1 visitors in-radius 4 with [not member? self xx and member? self available-visitors-set] ;; while informing conversation buddy, check if there are others nearby to inform
        if faster-model-timer3 = 0 and ( any? nearby-people1)[
          let nearby-people-informing-extra nearby-people1
          let nearby-people-informing-list-extra [self] of nearby-people-informing-extra
          let y scan-environment-counter

          if count nearby-people-informing-extra > 0 [
            foreach nearby-people-informing-list-extra [ person-informed-extra ->
              set people-informed lput person-informed-extra people-informed]
            ask nearby-people-informing-extra
            [ set conversationing-with-staff? true
              set conversationing-time-left y
              ifelse normal-state? = true
              [set informed-by-staff? true
                if notification-time-countoff > 5 [
                  set notification-time-countoff random 5]]
              [if response-state? = true
                [if informed-by-staff? = false [
                  set informed-by-staff? true
                  informed-by-staff-adjust-response-tasks
              ]]]
              set exit-destination min-one-of exit-possibilities [distance myself]]]]]

      [ set conversation-buddy 0                                                              ;; If done with informing conversation buddy, continue evacuation
        set looking-around-seek-info? false
        set path 99999
        set current-destination exit-destination]
  ]]

end
@#$#@#$#@
GRAPHICS-WINDOW
858
10
1453
576
-1
-1
2.9204
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
200
0
190
1
1
1
ticks
30.0

BUTTON
600
18
673
51
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
601
54
664
87
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
630
147
751
180
verbose?
verbose?
0
1
-1000

SWITCH
639
194
749
227
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
300
95.0
5
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
150
20.0
1
1
NIL
HORIZONTAL

MONITOR
119
402
224
447
Visitors evacuating
count visitors with [ evacuating-state? = True ]
17
1
11

BUTTON
676
55
753
88
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
1
12
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
120
200
140.0
5
1
NIL
HORIZONTAL

SLIDER
8
122
296
155
Familiarity-meter
Familiarity-meter
0
100
0.0
2
1
% of visitors familiar
HORIZONTAL

MONITOR
8
353
172
398
Total # of people inside building
count turtles with [ evacuated-state? = false ]
17
1
11

MONITOR
8
401
113
446
Staff evacuating
count staff with [ evacuating-state? =  True ]
17
1
11

MONITOR
8
451
109
496
Agents evacuated
count turtles with [ evacuated-state? =  True ]
1
1
11

PLOT
251
236
710
483
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
310
147
564
192
Exits-available
Exits-available
"All-exits" "Only-North-exit" "North-West" "North-East" "West-East" "West-only" "East-only"
0

BUTTON
685
15
748
48
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
215
523
743
681
11

SLIDER
8
160
297
193
Visitors-not-on-place
Visitors-not-on-place
0
50
20.0
1
1
% of visitors not on place
HORIZONTAL

SLIDER
8
233
245
266
chance-friends-nearby
chance-friends-nearby
0
100
75.0
2
1
NIL
HORIZONTAL

SLIDER
8
196
246
229
Chance-friends-in-building
Chance-friends-in-building
0
100
30.0
2
1
NIL
HORIZONTAL

CHOOSER
311
99
449
144
Culture
Culture
"Czech Republic" "Poland" "Turkey" "UK"
0

SLIDER
7
84
295
117
gender-ratio
gender-ratio
0
100
50.0
2
1
% men of whole population
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

The model shows the evacuation of the Library in TU Delft. A distinction has been made between two kinds of people within the model: staff and visitors. Staff are working in the library and are familiar with the building. Visitors can be students or other members of the general public within the library.
In this model, the focus is on response phase behaviour of visitors and how this is influenced by  national culture. Four countries have been considered for their national cultures: Czech Republic, Poland, Turkey and the UK.
Additionally the model includes the effects of cues, setting and affiliation on response phase behaviour for each country.

## HOW IT WORKS

All agents in the model will go trough three states: Normal state, Response state and Evacuating state.

After the model has run for 30 seconds, a fire occurs and an alarm starts ringing. At this point in time, a notification time is determined for all agents. Staff members will have a shorter notification time compared to visitors. The notification time can be further influenced by cues.

Both staff members and visitors will perform multiple tasks during the response phase. These depend on the situation which they are in and the cues which they have received. Per country, probabilities differ for performing each type of task. 

After finishing all tasks, the agents will start evacuation movement. 



## HOW TO USE IT

The model can be started and, if the alarm button has not been clicked, the fire and alarm start after 30 seconds. When the alarm button it clicked, the fire and alarm will start immediately.

There are many input parameters that can be decided on by the model user:
- Inital-number-staff: The number of staff members present within the building
- Inital-number-visitor: The number of visitors present within the building
- Gender-ratio: the percentage of the population that is men
- Familiarity-meter: the percentage of the population that is familiar with the building
- Vision-distance in patches: How many patches ahead an agent can look.
- Vision-angle: the angle widt of an agents vision
- Exits available: the availability of exits while running the model
- Culture: The culture for which the model runs
- Visitors-not-on-place: The percentage of visitors not located on their determined sitting place at the start of the simulation
- Chance-friends-in-building: The percentage of visitors which is part of a friend duo
- Chance-friends-nearby: The probability for friends being located nearby or not at the start of the simulation

A graph is shown with the interface, which provides real-time information during the run. 
The output box shows information on the evacuation, when the run has ended.


## THINGS TO NOTICE

It is interesting to see how turtles influence each other. 
For example how staff inform visitors and visitrs adjust their response tasks list due to this. Or how walking speeds of agents dependent upon the amount of other agents in their surroundings. 
Lastly, one can observe friends waiting and searching for each other before starting evacuation.

## THINGS TO TRY

It is suggested for the user to play with all the input parameters described above, to see the effects that these have on the simulation outcomes.

## EXTENDING THE MODEL

It would be suggested for further research to include some of the following elements in the model: 
- Other countries / cultures
- Extension of notification and evacuation phase behaviour
- Add extra influential factors during response phase: group behaviour, queueing, emotions, risk perceptions, knowledge sharing
- Improve modelling of response tasks through research on these tasks

## RELATED MODELS

There are no models in the Netlogo library, which show evacuation behaviour. There are many models available online on evacuation behaviour, none of these is focussed on the TU  Delft library. 

## CREDITS AND REFERENCES
Model developed by Elvira Van Damme.

The base of the model was developed by Syed Mujtaba Fardeen, Francien Baijanova and Elvira Van Damme. This included basic evacuation behaviour during all evacuation phases.

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
  <experiment name="Numvist200-300-1" repetitions="70" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2100"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notif] of staff</metric>
    <metric>[notif] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="200"/>
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;UK&quot;"/>
      <value value="&quot;Turkey&quot;"/>
      <value value="&quot;Czech Republic&quot;"/>
      <value value="&quot;Poland&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Numvist150familiarity0-25-2" repetitions="70" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2100"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notif] of staff</metric>
    <metric>[notif] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="0"/>
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;UK&quot;"/>
      <value value="&quot;Turkey&quot;"/>
      <value value="&quot;Czech Republic&quot;"/>
      <value value="&quot;Poland&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Numvist150familiarity75-3" repetitions="70" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2100"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notif] of staff</metric>
    <metric>[notif] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;UK&quot;"/>
      <value value="&quot;Turkey&quot;"/>
      <value value="&quot;Czech Republic&quot;"/>
      <value value="&quot;Poland&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Numvist150staff50-75-4" repetitions="70" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2100"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notif] of staff</metric>
    <metric>[notif] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;UK&quot;"/>
      <value value="&quot;Turkey&quot;"/>
      <value value="&quot;Czech Republic&quot;"/>
      <value value="&quot;Poland&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="50"/>
      <value value="75"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Numvist150groupsize0-15-60-5" repetitions="70" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2100"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notif] of staff</metric>
    <metric>[notif] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="0"/>
      <value value="15"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;UK&quot;"/>
      <value value="&quot;Turkey&quot;"/>
      <value value="&quot;Czech Republic&quot;"/>
      <value value="&quot;Poland&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Verification-numberstaff0" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notification-time] of staff</metric>
    <metric>[notification-time] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;Czech Republic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Verification-numberstaff100" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notification-time] of staff</metric>
    <metric>[notification-time] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;Czech Republic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Verification-chance-friends-in-building" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notification-time] of staff</metric>
    <metric>[notification-time] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="100"/>
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;Czech Republic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Verification-vision-distance2" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notification-time] of staff</metric>
    <metric>[notification-time] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;Czech Republic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Verification-vision-distance20" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notification-time] of staff</metric>
    <metric>[notification-time] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;Czech Republic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Verification-vision-angle" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notification-time] of staff</metric>
    <metric>[notification-time] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="60"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;Czech Republic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Verification-visitors-not-in-place" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notification-time] of staff</metric>
    <metric>[notification-time] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;Czech Republic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="0"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Verification-familiarity0-100" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>total-evacuation-time</metric>
    <metric>[ response-time ] of visitors</metric>
    <metric>[ response-time ] of staff</metric>
    <metric>[evacuation-time] of visitors</metric>
    <metric>[evacuation-time] of staff</metric>
    <metric>[notification-time] of staff</metric>
    <metric>[notification-time] of visitors</metric>
    <metric>[response-time-excl-notif] of staff</metric>
    <metric>[response-time-excl-notif] of visitors</metric>
    <metric>[movement-time] of staff</metric>
    <metric>[movement-time] of visitors</metric>
    <metric>[response-tasks-list] of visitors</metric>
    <metric>count staff with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [ evacuated-state? =  True ]</metric>
    <metric>count visitors with [informed-by-staff? = True]</metric>
    <metric>count visitors with [fire-seen? = True]</metric>
    <enumeratedValueSet variable="Exits-available">
      <value value="&quot;All-exits&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Familiarity-meter">
      <value value="0"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-visitor">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-friends-in-building">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gender-ratio">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture">
      <value value="&quot;Czech Republic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-friends-nearby">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Visitors-not-on-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-staff">
      <value value="20"/>
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
