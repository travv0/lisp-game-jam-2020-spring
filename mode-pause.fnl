(local tiled (require "lib.sti"))
(local map (tiled "tilebackground.lua" ["bump"]))

{:draw (fn draw []
         (map:draw))
 :update (fn [])
 :keypressed (fn keypressed [key set-mode]
               (when (= key "escape")
                 (set-mode "mode-game")))}
