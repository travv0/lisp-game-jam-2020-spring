(local tiled (require "lib.sti"))
(local bump (require "bump"))

(fn lint [map]
  (each [_ wall (ipairs map.layers.walls.objects)]
        (assert wall.properties.collidable "Missing wall collidable!"))
  map)

(local map (lint (tiled "test.lua" ["bump"])))
(local world (bump.newWorld))

(local (width height) (love.window.getMode))

(local state {:player {:speed 200 :scale 1}
              :obstacle {}
              :bugs []
              :map map
              :world world})

(global s state)

(var current-key "")

(map:bump_init world)
(world:add state.player (/ width 2) (/ height 2) 32 32)
(world:add state.obstacle 200 50 32 32)

(local player-img (love.graphics.newImage "assets/player.png"))
(local worm-img (love.graphics.newImage "assets/worm.png"))

(fn make-progress [min-hit max-hit after speed]
  {:current 0
   :end 100
   :min-hit min-hit
   :max-hit max-hit
   :speed (or speed 5)
   :after after})

(fn make-bug [x y]
  {:x x :y y
   :speed 100
   :state :moving
   :progress (make-progress 70 80 (fn [progress] (set progress.current 0)))})

(fn spawn-bug []
  (let [side (lume.randomchoice [:top :right :bottom: :left])
        offset (if (or (= side :top) (= side :bottom))
                   (math.random width)
                   (math.random height))
        bug (if (= side :top)
                (make-bug offset 0)
                (= side :bottom)
                (make-bug offset height)
                (= side :left)
                (make-bug 0 offset)
                (make-bug width offset))]
    (table.insert state.bugs bug)
    (world:add bug bug.x bug.y 32 32)))

(fn within? [item box margin]
  (let [(x y width height) (world:getRect item)]
    (and (< (- box.x margin) x (+ x width) (+ (+ box.x box.width) margin))
         (< (- box.y margin) y (+ y height) (+ (+ box.y box.height) margin)))))

(fn wall-check [cols unit set-mode]
  (set state.player.in-wall? false)
  (each [_ col (ipairs cols)]
        (when (and col.other.properties col.other.properties.wall
                   (within? col.item col.other 0))
          (set unit.in-wall? true)
          (when (not unit.in-wall-last-tick?)
            (set-mode :wall col.other.properties.wall)))))

(fn move-player [dt set-mode]
  (let [left? (if (love.keyboard.isDown "left") 1 0)
        right? (if (love.keyboard.isDown "right") 1 0)
        up? (if (love.keyboard.isDown "up") 1 0)
        down? (if (love.keyboard.isDown "down") 1 0)]
    (when (> (+ left? right? up? down?) 0)
      (let [(x y) (world:getRect state.player)
            new-x (+ x
                     (- (* left? state.player.speed dt))
                     (* right? state.player.speed dt))
            new-y (+ y
                     (- (* up? state.player.speed dt))
                     (* down? state.player.speed dt))
            (_ _ cols) (world:move state.player new-x new-y (fn [] :slide))]
        (wall-check cols state.selected set-mode)))))

(fn update-progress [dt set-mode progress]
  (set progress.current (+ progress.current (* progress.speed dt)))
  (when (>= progress.current progress.end)
    (progress:after)))

(fn update-bugs [dt set-mode]
  (let [(player-x player-y) (world:getRect state.player)]
    (each [_ bug (pairs state.bugs)]
          (let [(bug-x bug-y) (world:getRect bug)
                angle (lume.angle bug-x bug-y player-x player-y)
                (dx dy) (lume.vector angle (* bug.speed dt))]
            (world:move bug (+ bug-x dx) (+ bug-y dy) (fn [] :slide)))
          (update-progress dt set-mode bug.progress))))

(fn draw [message]
  (map:draw)
  (love.graphics.print (: "Currently pressed key: %s"
                        :format current-key) 32 16)
  (let [(x y) (world:getRect state.player)]
    (love.graphics.draw player-img x y))
  (let [(x y) (world:getRect state.obstacle)]
    (love.graphics.draw player-img x y))
  (each [_ bug (ipairs state.bugs)]
        (let [(x y) (world:getRect bug)]
          (love.graphics.draw worm-img x y))))

{:draw draw
 :update (fn update [dt set-mode]
           (when (= (math.random (/ 2 dt)) 1)
             (spawn-bug))
           (move-player dt set-mode)
           (update-bugs dt set-mode))
 :keypressed (fn keypressed [key set-mode]
               (set current-key key))}
