(local tiled (require "lib.sti"))
(local map (tiled "test.lua" ["bump"]))

{:draw (fn draw []
         (map:draw))
 :update (fn [])
 :keypressed (fn keypressed [key set-mode]
               (when (= key "escape")
                 (set-mode "mode-game")))}
