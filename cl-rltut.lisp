;;;; cl-rltut.lisp

(in-package #:cl-rltut)

(defparameter *screen-width* 80)
(defparameter *screen-height* 50)
(defparameter *color-map*
  (list :dark-wall (blt:rgba 0 0 50)
	:dark-ground (blt:rgba 50 100 150)
	:light-wall (blt:rgba 130 110 50)
	:light-ground (blt:rgba 200 180 50)))

(defparameter *map-width* 80)
(defparameter *map-height* 45)
(defparameter *map* nil)

(defparameter *room-max-size* 10)
(defparameter *room-min-size* 6)
(defparameter *max-rooms* 30)

(defparameter *max-enemies-per-room* 8)

(deftype game-states () '(member :player-turn :enemy-turn :exit))

(defclass entity ()
  ((name :initarg :name :accessor entity/name)
   (x :initarg :x :accessor entity/x)
   (y :initarg :y :accessor entity/y)
   (char :initarg :char :accessor entity/char)
   (color :initarg :color :accessor entity/color)
   (blocks :initarg :blocks :accessor entity/blocks)))

(defmethod move ((e entity) dx dy)
  (incf (entity/x e) dx)
  (incf (entity/y e) dy))

(defmethod draw ((e entity) (map game-map))
  (with-slots (x y char color) e
    (if (tile/visible (aref (game-map/tiles map) x y))
	(setf
	 (blt:background-color) (blt:cell-background-color x y)
	 (blt:color) color
	 (blt:cell-char x y) char))))

(defun render-all (entities map)
  (blt:clear)
  (dotimes (y (game-map/h map))
    (dotimes (x (game-map/w map))
      (let* ((tile (aref (game-map/tiles map) x y))
	     (wall (tile/blocked tile))
	     (visible (tile/visible tile))
	     (explored (tile/explored tile)))
	(cond (visible
	       (if wall
		   (setf (blt:background-color) (getf *color-map* :light-wall))
		   (setf (blt:background-color) (getf *color-map* :light-ground)))
	       (setf (blt:cell-char x y) #\Space))
	      (explored
	       (if wall
		   (setf (blt:background-color) (getf *color-map* :dark-wall))
		   (setf (blt:background-color) (getf *color-map* :dark-ground)))
	       (setf (blt:cell-char x y) #\Space))))))

  (mapc #'(lambda (entity) (draw entity map)) entities)

  (setf (blt:background-color) (blt:black))
  (blt:refresh))

(defun handle-keys ()
  (let ((action nil))
    (blt:key-case (blt:read)
		  (:up (setf action (list :move (cons 0 -1))))
		  (:down (setf action (list :move (cons 0 1))))
		  (:left (setf action (list :move (cons -1 0))))
		  (:right (setf action (list :move (cons 1 0))))
		  (:k (setf action (list :move (cons 0 -1))))
		  (:j (setf action (list :move (cons 0 1))))
		  (:h (setf action (list :move (cons -1 0))))
		  (:l (setf action (list :move (cons 1 0))))
		  (:y (setf action (list :move (cons -1 -1))))
		  (:u (setf action (list :move (cons 1 -1))))
		  (:b (setf action (list :move (cons -1 1))))
		  (:n (setf action (list :move (cons 1 1))))
		  (:escape (setf action (list :quit t)))
		  (:close (setf action (list :quit t))))
    action))

(defun config ()
  (blt:set "window.resizeable = true")
  (blt:set "window.size = ~Ax~A" *screen-width* *screen-height*)
  (blt:set "window.title = Roguelike"))

(defun game-tick (player entities map game-state)
  (declare (type game-states game-state))
  (render-all entities map)
  (let* ((action (handle-keys))
	 (move (getf action :move))
	 (exit (getf action :quit)))
    (when move
      (let ((destination-x (+ (entity/x player) (car move)))
	    (destination-y (+ (entity/y player) (cdr move))))
	(unless (blocked-p map destination-x destination-y)
	  (let ((target (blocking-entity-at entities destination-x destination-y)))
	    (cond (target
		   (format t "You kick the ~A.~%" (entity/name target)))
		  (t
		   (move player (car move) (cdr move))
		   (fov map (entity/x player) (entity/y player)))))
	  (setf game-state :enemy-turn))))

    (when exit (setf game-state :exit)))

  (when (eql game-state :enemy-turn)
    (dolist (entity entities)
      (unless (eql entity player)
	(cond ((string= (entity/name entity) "Orc")
	       (format t "The ~A snores loudly.~%" (entity/name entity)))
	      (t
	       (format t "The ~A sits idly.~%" (entity/name entity))))))
    (setf game-state :player-turn))

  game-state)

(defun main ()
  (blt:with-terminal
    (config)
    (let* ((player (make-instance 'entity
				  :name "Player"
				  :x (/ *screen-width* 2)
				  :y (/ *screen-height* 2)
				  :char #\@
				  :color (blt:white)
				  :blocks t))
	   (entities (list player))
	   (map (make-instance 'game-map :w *map-width* :h *map-height*)))
      (make-map map *max-rooms* *room-min-size* *room-max-size* *map-width* *map-height* player entities *max-enemies-per-room*)
      (fov map (entity/x player) (entity/y player))

      (do ((game-state :player-turn (game-tick player entities map game-state)))
	  ((eql game-state :exit))))))
