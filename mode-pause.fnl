(local tiled (require "lib.sti"))
(local map (tiled "test.lua" ["bump"]))

{:draw (fn draw []
         (map:draw))
 :update (fn [])
 :keypressed (fn keypressed [key set-mode]
               (when (= key "p")
                 (set-mode "mode-game")))}
