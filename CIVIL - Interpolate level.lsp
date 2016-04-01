(defun c:INT( /
              *error*
              set_line reference_circle1 reference_circle2
              mode grad cota level
              p1 p2 p3 p4
              z1 z2 z3 z4
              d12 d13 d14
              ang12 ang123 ang13 ang21
              u0 v0 w0
              oldosmode oldcmdecho oldclayer
            )
  ; SET - Error handling function
  (defun *error* ( msg )
    (if (not (member msg '("Function cancelled" "quit / exit abort")))
      (princ (strcat "\nError: " msg))
    )
    ; OPERATION - Delete auxiliary data, if any
    (if (/= set_line nil) (vla-delete (vlax-ename->vla-object set_line)))
    (if (/= reference_circle1 nil) (vla-delete (vlax-ename->vla-object reference_circle1)))
    (if (/= reference_circle2 nil) (vla-delete (vlax-ename->vla-object reference_circle2)))

    ; Restore previous settings
    (setvar "osmode" oldosmode)
    (setvar "cmdecho" oldcmdecho)
    (setvar "clayer" oldclayer)
    (princ)
  )

  ; OPERATION - Borrar datos auxiliares, por si existen
  (setq set_line nil)

  ; SAVE CURRENT SETTINGS - Current layer, OSMODE and CMDECHO
  (setq oldosmode (getvar "osmode")
        oldcmdecho (getvar "cmdecho")
        oldclayer (getvar "clayer")
  )

  ; OPERATION - Check if function library is loaded. If not, exit.
  (princ "\nLooking for function library... ")
  (if (and
        (= (eval DT:input_string_or_point) nil)
        (= (eval DT:clic_or_type_level) nil)
      );END and
    (progn
      (princ "required library not found.\nPlease, load function library and run command again.")
      (exit)
    )
    (princ "loaded.")
  )

  ;turn off the system echo
  (setvar "cmdecho" 0)

  ; OPERATION - Delete auxiliary data, if any
  (if (/= set_line nil) (vla-delete (vlax-ename->vla-object set_line)))
  (if (/= reference_circle1 nil) (vla-delete (vlax-ename->vla-object reference_circle1)))
  (if (/= reference_circle2 nil) (vla-delete (vlax-ename->vla-object reference_circle2)))

  ; INPUT - Point 1 and its level
  (setq p1 (getpoint "\nSelect point A: "))
  (setq z1 (DT:clic_or_type_level))
  (princ "\nLevel A = ")(princ z1)(princ "m")

  ; OPERATION - Create auxiliary data and objects
  (setq
    real_radius 8
    correction_factor 0.001
    radius (* real_radius (* correction_factor (getvar "viewsize")))  ; Calculate circle size at curent zoom

    reference_circle1 ( _Reference_Circle p1 radius)
  )

  ; INPUT - Point 2 and its level
  (setq p2 (getpoint "\nSelect point B: "))
  (setq z2 (DT:clic_or_type_level))
  (princ "\nLevel B = ")(princ z2)(princ "m")

  ; OPERATION - Create auxiliary data and objects
  (setq
    set_line ( _Set_Line p1 p2)
    reference_circle2 ( _Reference_Circle p2 radius)
  )

  ; INPUT - Choose action: pick, find, lowpoint
  (initget "Pick Find Lowpoint")
  (setq mode (getkword "\nSelect what to do [Pick/Find/Lowpoint] points <Pick>: "))
  (if (not mode) (setq mode "Pick"))

  (setq variable_vacia nil)
  (cond
    ((= mode "Pick") ; Clic and return point level
      (while (= variable_vacia nil)
        ; INPUT - Point 3
        (setvar "osmode" 545)
        (setq p3 (getpoint "\nSelect point to get level (or press Esc to exit): "))
        (if (not p3) (exit))
        (setq
          d12 (distance p1 p2)                ; Distance 1-2
          d13 (distance p1 p3)                ; Distance 1-3
          ang12 (angle p1 p2)                 ; Angle 1-2
          ang13 (angle p1 p3)                 ; Angle 1-3
          ang123 (- ang13 ang12)              ; Angle 1-3
          d14 (* d13 (cos ang123))            ; Distance 1-4
          p4 (polar p1 ang12 d14)             ; Point 4 (intersection between p1-p2 line and a second line perpendicular to p1-p2 line which contains p3)
          z4 (+ z1 (* d14 (/ (- z2 z1) d12))) ; Calculate leves
          level (rtos z4 2 3)                  ; Convert levels to text (3 decimals)
        ); END setq
        (princ (strcat "\nLevel = " level))

        ; OPERATION - Introduce point 4
        (setvar "osmode" 0)
        (command "._insert" "PI_DT" p4 "0.5" "0.5" "" level)
      ); END while Pick
    ); END cond Pick
    ((= mode "Find") ; Introduce level and return point
      (while (= variable_vacia nil)
        ; INPUT - Level 3
        (setq z3 (getreal "\nIntroduce level to get point (or press Esc to exit): "))
        (if (not z3) (exit))
        (setq
          d12 (distance p1 p2)                ; Distance 1-2
          p1 (list (car p1) (cadr p1) z1 )    ; Convert p1 to 3D point
          p2 (list (car p2) (cadr p2) z2 )    ; Convert p2 to 3D point
          u0 (- (car p2) (car p1))            ; Unit vector u
          v0 (- (cadr p2) (cadr p1))          ; Unit vector v
          w0 (- (caddr p2) (caddr p1))        ; Unit vector w
          d13 (/ (- z3 (caddr p1)) w0)        ; Distance 1-3
          x3 (+ (car p1)  (* d13 u0) )        ; X coordinate
          y3 (+ (cadr p1) (* d13 v0) )        ; y coordinate
          p3 (list x3 y3 0)                   ; Point 3
          level (rtos z3 2 3)                  ; Convert level to text (3 decimals)
        ); END setq
        (princ (strcat "\nLevel = " level))

        ; OPERATION - Introducir punto 3
        (setvar "osmode" 0)
        (command "._insert" "PI_DT" p3 "0.5" "0.5" "" level)
      ); END while Find
    ); END cond Find
    ((= mode "Lowpoint") ; Introduce gradient and return low point
      ; INPUT - Gradient
      (setq grad (getint "\nSelect minimum gradient <1/80>: "))
      (if (not grad) (setq grad 80))
      (setq
        ang12 (angle p1 p2)                 ; Angle 1-2
        ang21 (angle p2 p1)                 ; Angle 2-1
        d23 (* (- z2 z1) grad)              ; Distance 2-3
        p3 (polar p2 ang21 d23)             ; Point 3 (same level as point 1)
        d13 (distance p1 p3)                ; Distance 1-3
        d14 (* 0.5 d13)                     ; Distance 1-4
        p4 (polar p1 ang12 d14)             ; Point 4
        z4 (- z1 (/ d14 grad))              ; Level 4
        level (rtos z4 2 3)                  ; Convert level to text (3 decimals)
      ); END setq
      (princ (strcat "\nLevel = " level))

      ; OPERATION - Introduce point 3
      (setvar "osmode" 0)
      (command "._insert" "PI_DT" p4 "0.5" "0.5" "" level)
    ); END cond Find
  ); END cond

  ; OPERATION - Delete auxiliary data, if any
  (if (/= set_line nil) (vla-delete (vlax-ename->vla-object set_line)))
  (if (/= reference_circle1 nil) (vla-delete (vlax-ename->vla-object reference_circle1)))
  (if (/= reference_circle2 nil) (vla-delete (vlax-ename->vla-object reference_circle2)))

  ; Restore previous settings
  (setvar "osmode" oldosmode)
  (setvar "cmdecho" oldcmdecho)
  (setvar "clayer" oldclayer)

  ; End without double messages
  (princ)

  ; v0.6 - 2016.04.01 - Change level input function.
  ; v0.5 - 2016.03.22 - Optimize code.
  ;                   - Fix minor bugs.
  ;                   - Translate into English
  ; v0.4 - 2016.03.21 - Optimize code and translate partialy into English
  ; v0.3 - 2016.03.18 - Add feature: find low point with a given gradient
  ; v0.2 - 2016.03.17 - Move text extraction functions to library
  ;                   - Add feature: find a point from a given level
  ;                   - Optimize code
  ; v0.1 - 2016.03.14 - Loop added to select multiple points to interpolate
  ; v0.0 - 2015.12.14 - First issue
  ; Author: David Torralba
  ; Last revision: 2016.04.01
)
