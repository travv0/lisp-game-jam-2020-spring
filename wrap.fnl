(local repl (require "lib.stdio"))
(local canvas (let [(w h) (love.window.getMode)]
                (love.graphics.newCanvas w h)))
(local view (require :fennelview))

(var scale 1)

;; set the first mode
(var mode (require "mode-game"))

(fn set-mode [mode-name ...]
  (set mode (require mode-name))
  (when mode.activate
    (mode.activate ...)))

(fn love.load []
  (canvas:setFilter "nearest" "nearest")
  (repl.start))

(fn love.draw []
  ;; the canvas allows you to get sharp pixel-art style scaling; if you
  ;; don't want that, just skip that and call mode.draw directly.
  (love.graphics.setCanvas canvas)
  (love.graphics.clear)
  (love.graphics.setColor 1 1 1)
  (mode.draw)
  (let [(width height) (love.window.getMode)]
    (love.graphics.setColor 1 1 1)
    (love.graphics.print "Use the WASD keys to move.  When a bug glows yellow, it's vulnerable.  Press an arrow key in its direction to shoot it when it is in this state.\nDon't shoot when there are no vulnerable bugs or your gun will backfire!  Use the Esc key to pause, and the R key to restart."
                         32 (- height 32)))
  (love.graphics.setCanvas)
  (love.graphics.setColor 1 1 1)
  (love.graphics.draw canvas 0 0 0 scale scale))

(fn love.update [dt]
  (mode.update dt set-mode))

(fn love.keypressed [key]
  (if (and (love.keyboard.isDown "lctrl" "rctrl" "capslock") (= key "q"))
      (love.event.quit)
      ;; add what each keypress should do in each mode
      (mode.keypressed key set-mode)))

(fn start-repl []
  (let [code (love.filesystem.read "stdio.fnl")
        lua_ (love.filesystem.newFileData (fennel.compileString code) "io")
        thread (love.thread.newThread lua_)
        io-channel (love.thread.newChannel)]
    ;; this thread will send "eval" events for us to consume:
    (: thread :start "eval" io-channel)
    (set love.handlers.eval
         (fn [input]
           (let [(ok val) (pcall fennel.eval input)]
             (: io-channel :push (if ok (view val) val)))))))
