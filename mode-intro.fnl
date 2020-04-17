(local bump (require "bump"))
(local world (bump.newWorld))

(local state {:player {:speed 200}
              :obstacle {}})

(var current-key "")

(: world :add state.player 50 50 32 32)
(: world :add state.obstacle 200 50 32 32)

(local player-img (love.graphics.newImage "player.png"))

(fn within? [item box margin]
  (let [(x y width height) (: world :getRect item)]
    (and (< (- box.x margin) x (+ x width) (+ (+ box.x box.width) margin))
         (< (- box.y margin) y (+ y height) (+ (+ box.y box.height) margin)))))

(fn terminal-check [cols unit set-mode]
  (set state.player.in-term? false)
  (each [_ col (ipairs cols)]
    (when (and col.other.properties col.other.properties.terminal
               (within? col.item col.other 0))
      (set unit.in-term? true)
      (when (not unit.in-term-last-tick?)
        (set-mode :term col.other.properties.terminal)))))

(fn move-player [dt set-mode]
  (let [left? (if (love.keyboard.isDown "left") 1 0)
        right? (if (love.keyboard.isDown "right") 1 0)
        up? (if (love.keyboard.isDown "up") 1 0)
        down? (if (love.keyboard.isDown "down") 1 0)]
    (when (> (+ left? right? up? down?) 0)
      (let [(x y) (: world :getRect state.player)
            new-x (+ x
                     (- (* left? state.player.speed dt))
                     (* right? state.player.speed dt))
            new-y (+ y
                     (- (* up? state.player.speed dt))
                     (* down? state.player.speed dt))
            (_ _ cols) (: world :move state.player new-x new-y (fn [] :slide))]
        (terminal-check cols state.selected set-mode)))))

{:draw (fn draw [message]
         (love.graphics.print (: "Currently pressed key: %s"
                               :format current-key) 32 16)
         (let [(x y) (: world :getRect state.player)]
           (love.graphics.draw player-img x y 0.025 0.025))
         (let [(x y) (: world :getRect state.obstacle)]
           (love.graphics.draw player-img x y 0.025 0.025)))
 :update (fn update [dt set-mode]
           (move-player dt set-mode))
 :keypressed (fn keypressed [key set-mode]
               (set current-key key))}
