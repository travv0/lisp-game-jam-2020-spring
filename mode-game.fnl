(local tiled (require "lib.sti"))
(local bump (require "bump"))

(fn lint [map]
  (each [_ wall (ipairs map.layers.walls.objects)]
    (assert wall.properties.collidable "Missing wall collidable!"))
  map)

(local map (lint (tiled "test.lua" ["bump"])))
(local world (bump.newWorld))

(local (width height) (love.window.getMode))

(local gunshot-sound (love.audio.newSource "assets/gunshot.wav" :static))
(local game-over-sound (love.audio.newSource "assets/gameover.wav" :static))
(local laser-sound (love.audio.newSource "assets/laser.wav" :static))

(fn make-muzzle-flash [x y direction backfire]
  {:x x :y y
   :direction direction
   :time 0.05
   :backfire backfire})

(fn player-shoot [player state direction]
  (let [(player-x player-y) (world:getRect player)
        dead-bugs []]
    (each [i bug (lume.ripairs state.bugs)]
      (when (bug:exposed?)
        (let [(bug-x bug-y) (world:getRect bug)
              angle (lume.angle player-x player-y bug-x bug-y)]
          (when (or (and (= direction :right) (<= (lume.angle 0 0 1 -2) angle (lume.angle 0 0 1 2)))
                    (and (= direction :up) (<= (lume.angle 0 0 -2 -1) angle (lume.angle 0 0 2 -1)))
                    (and (= direction :down) (<= (lume.angle 0 0 2 1) angle (lume.angle 0 0 -2 1)))
                    (and (= direction :left) (or (>= angle (lume.angle 0 0 -1 2))
                                                 (<= angle (lume.angle 0 0 -1 -2)))))
            (table.insert dead-bugs [i bug])))))
    (if (= direction :left)
        (set player.facing :left)
        (= direction :right)
        (set player.facing :right))
    (if (= (table.getn dead-bugs) 0)
        (do (set player.state :dead)
            (gunshot-sound:stop)
            (gunshot-sound:setVolume 2)
            (gunshot-sound:play)
            (table.insert state.muzzle-flashes (make-muzzle-flash player-x player-y direction true)))
        (do (gunshot-sound:stop)
            (gunshot-sound:setVolume 1)
            (gunshot-sound:play)
            (table.insert state.muzzle-flashes (make-muzzle-flash player-x player-y direction))))
    (each [_ [i bug] (pairs dead-bugs)]
      (set state.score (+ state.score 100))
      (let [(bug-x bug-y) (world:getRect bug)]
        (table.insert state.dead-bugs {:x bug-x :y bug-y :bug-type bug.bug-type :facing bug.facing}))
      (table.remove state.bugs i)
      (world:remove bug))))

(var state {})

(var hi-score 0)

(fn init []
  (set state {:player {:speed 200
                       :scale 1
                       :shoot player-shoot
                       :state :alive
                       :type :player
                       :facing :right
                       :shooting {:direction :right
                                  :duration 0}}
              :obstacle {}
              :bugs []
              :dead-bugs []
              :muzzle-flashes []
              :score 0
              :game-over false
              :map map
              :world world})
  (map:bump_init world)
  (world:add state.player (/ width 2) (/ height 2) 32 32)
  (world:add state.obstacle 200 50 32 32))

(init)

(fn re-init []
  (each [_ item (pairs (world:getItems))]
    (world:remove item))
  (init))

(global s state)

(local player-img (love.graphics.newImage "assets/playerpistol.png"))
(local dead-player-img (love.graphics.newImage "assets/deadplayer.png"))
(local worm-img (love.graphics.newImage "assets/worm.png"))
(local dead-worm-img (love.graphics.newImage "assets/deadworm.png"))
(local bug-img (love.graphics.newImage "assets/bug.png"))
(local dead-bug-img (love.graphics.newImage "assets/deadbug.png"))
(local muzzle-flash-img (love.graphics.newImage "assets/flash.png"))

(fn make-progress [min-hit max-hit after speed]
  {:current (lume.random 0 (/ min-hit 2))
   :end 100
   :min-hit min-hit
   :max-hit max-hit
   :speed (or speed 25)
   :after after})

(fn bug-shoot [bug]
  (set bug.state :shooting))

(fn bug-speed [type]
  (if (= type :worm) 150
      (= type :bug) 300))

(fn bug-progress [type]
  (if (= type :worm)
      (make-progress 80 100 (fn [progress] (progress.parent:shoot)))
      (= type :bug)
      (make-progress 50 100 (fn [progress] (set progress.current 0)) 70)))

(fn make-bug [x y type]
  (let [bug {:x x :y y
             :speed (bug-speed type)
             :state :moving
             :type :bug
             :bug-type type
             :state-time 0
             :progress (bug-progress type)
             :exposed? (fn [self] (<= self.progress.min-hit
                                      self.progress.current
                                      self.progress.max-hit))
             :shoot bug-shoot
             :angle 0
             :facing :right}]
    (set bug.progress.parent bug)
    bug))

(fn spawn-bug []
  (let [side (lume.randomchoice [:top :right :bottom: :left])
        type (lume.weightedchoice {:worm 3 :bug 1})
        offset (if (or (= side :top) (= side :bottom))
                   (math.random width)
                   (math.random height))
        bug (if (= side :top)
                (make-bug offset 0 type)
                (= side :bottom)
                (make-bug offset height type)
                (= side :left)
                (make-bug 0 offset type)
                (make-bug width offset type))]
    (table.insert state.bugs bug)
    (world:add bug bug.x bug.y 32 32)))

(fn move-player [dt set-mode]
  (when (= state.player.state :alive)
    (let [left? (if (love.keyboard.isDown "a") 1 0)
          right? (if (love.keyboard.isDown "d") 1 0)
          up? (if (love.keyboard.isDown "w") 1 0)
          down? (if (love.keyboard.isDown "s") 1 0)]
      (when (> (+ left? right? up? down?) 0)
        (let [(x y) (world:getRect state.player)
              x-speed (+ (- (* left? state.player.speed dt))
                         (* right? state.player.speed dt))
              new-x (+ x x-speed)
              new-y (+ y
                       (- (* up? state.player.speed dt))
                       (* down? state.player.speed dt))]
          (set state.player.facing (if (< x-speed 0) :left :right))
          (world:move state.player new-x new-y (fn [] :slide)))))))

(fn update-progress [dt set-mode progress]
  (set progress.current (+ progress.current (* progress.speed dt)))
  (when (>= progress.current progress.end)
    (progress:after)))

(fn update-bugs [dt set-mode]
  (let [(player-x player-y) (world:getRect state.player)]
    (each [_ bug (pairs state.bugs)]
      (when (and (= bug.state :moving)
                 (not (= state.player.state :dead)))
        (let [(bug-x bug-y) (world:getRect bug)
              angle (lume.angle bug-x bug-y player-x player-y)
              (dx dy) (lume.vector angle (* bug.speed dt))
              (_ _ cols) (world:move bug (+ bug-x dx) (+ bug-y dy) (fn [] :cross))]
          (set bug.angle angle)
          (if (<= (lume.angle 0 0 0 -1) bug.angle (lume.angle 0 0 0 1))
              (set bug.facing :left)
              (set bug.facing :right))
          (each [_ col (pairs cols)]
            (when (= col.other.type :player)
              (set col.other.state :dead)))
          (update-progress dt set-mode bug.progress)))
      (when (= bug.state :shooting)
        (when (= bug.state-time 0)
          (laser-sound:stop)
          (laser-sound:play))
        (set bug.state-time (+ bug.state-time dt))
        (when (>= bug.state-time 1)
          (set state.player.state :dead))
        (when (>= bug.state-time 6)
          (set bug.state :done)
          (set bug.state-time 0))))))

(fn update-muzzle-flashes [dt set-mode]
  (each [i mf (lume.ripairs state.muzzle-flashes)]
    (set mf.time (- mf.time dt))
    (when (<= mf.time 0)
      (table.remove state.muzzle-flashes i))))

(fn bug-angle [bug]
  (if (= bug.bug-type :bug)
      (+ bug.angle math.pi (/ math.pi 4))
      0))

(fn bug-x-mirror [bug]
  (if (= bug.bug-type :bug)
      1
      (= bug.facing :left)
      -1
      1))

(fn draw-bug [bug player-x player-y]
  (let [(x y w h) (world:getRect bug)
        img (if (= bug.bug-type :worm) worm-img
                (= bug.bug-type :bug) bug-img)]
    (love.graphics.draw img x y (bug-angle bug) (bug-x-mirror bug) 1 (/ w 2) (/ h 2))
    (when (bug:exposed?)
      (let [a-val (- 0.5 (/ (- bug.progress.current bug.progress.min-hit)
                            (- bug.progress.max-hit bug.progress.min-hit)
                            2))]
        (love.graphics.setColor 1 1 0 a-val)
        (love.graphics.circle :fill x y 32)
        (love.graphics.setColor 1 0 0)))
    (when (= bug.state :shooting)
      (love.graphics.setColor 1 0 0)
      (love.graphics.setLineWidth 5)
      (love.graphics.line x y player-x player-y)
      (love.graphics.setColor 1 1 1))))

(fn draw [message]
  (map:draw)
  (love.graphics.print (: "Score: %15.0f" :format state.score) 32 16)
  (love.graphics.print (: "High Score: %15.0f" :format hi-score) (- width 178) 16)
  (let [(player-x player-y player-w player-h) (world:getRect state.player)
        current-player-img (if (= state.player.state :dead) dead-player-img player-img)]
    (each [_ bug (pairs state.dead-bugs)]
      (love.graphics.draw (if (= bug.bug-type :worm) dead-worm-img
                              (= bug.bug-type :bug) dead-bug-img)
                          bug.x
                          bug.y
                          0
                          (if (= bug.facing :right) 1 -1)
                          1
                          16
                          16))
    (love.graphics.draw current-player-img
                        player-x
                        player-y
                        0
                        (if (= state.player.facing :right) 1 -1)
                        1
                        (/ player-w 2)
                        (/ player-h 2))
    (each [_ bug (pairs state.bugs)]
      (draw-bug bug player-x player-y))
    (each [_ mf (pairs state.muzzle-flashes)]
      (love.graphics.setColor 1 1 1)
      (love.graphics.draw muzzle-flash-img
                          mf.x
                          mf.y
                          (if (= mf.direction :up)
                              (- (/ math.pi 2))
                              (= mf.direction :left)
                              math.pi
                              (= mf.direction :down)
                              (/ math.pi 2)
                              0)
                          (if mf.backfire 3 1)
                          (if mf.backfire 3 1)
                          (if mf.backfire 0 (/ player-w -2))
                          (/ player-h 2)))))

(fn game-over []
  (game-over-sound:play)
  (set state.game-over true))

{:draw draw
 :update (fn update [dt set-mode]
           (when (and (= state.player.state :dead)
                      (not state.game-over))
             (game-over))
           (when (not (= state.player.state :dead))
             (set state.score (+ state.score (* 100 dt))))
           (when (or (= (table.getn state.bugs) 0)
                     (and (not (= state.player.state :dead))
                          (= (math.random (/ (- 2 (/ state.score 10000)) dt)) 1)))
             (spawn-bug))
           (move-player dt set-mode)
           (update-muzzle-flashes dt set-mode)
           (update-bugs dt set-mode)
           (when (> state.score hi-score)
             (set hi-score state.score)))
 :keypressed (fn keypressed [key set-mode]
               (if (= key "r") (re-init)
                   (= key "escape") (set-mode "mode-pause"))
               (when (not (= state.player.state :dead))
                 (if (= key "right")
                     (state.player:shoot state :right)
                     (= key "up")
                     (state.player:shoot state :up)
                     (= key "left")
                     (state.player:shoot state :left)
                     (= key "down")
                     (state.player:shoot state :down))))}
