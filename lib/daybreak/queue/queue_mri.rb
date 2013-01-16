module Daybreak
  class Queue
    # HACK: Dangerous optimization on MRI which has a
    # global interpreter lock and makes the @queue array
    # thread safe.
    def initialize
      @queue, @full, @empty = [], [], []
      @stop = false
      @heartbeat = Thread.new(&method(:heartbeat))
      @heartbeat.priority = -9
    end

    def <<(x)
      @queue << x
      thread = @full.first
      thread.wakeup if thread
    end

    def pop
      @queue.shift
      if @queue.empty?
        thread = @empty.first
        thread.wakeup if thread
      end
    end

    def next
      while @queue.empty?
        begin
          @full << Thread.current
          # If a push happens before Thread.stop, the thread won't be woken up
          Thread.stop while @queue.empty?
        ensure
          @full.delete(Thread.current)
        end
      end
      @queue.first
    end

    def flush
      until @queue.empty?
        begin
          @empty << Thread.current
          # If a pop happens before Thread.stop, the thread won't be woken up
          Thread.stop until @queue.empty?
        ensure
          @empty.delete(Thread.current)
        end
      end
    end

    def stop
      @stop = true
      @heartbeat.join
    end

    private

    # Check threads 10 times per second to avoid deadlocks
    # since there is a race condition below
    def heartbeat
      until @stop
        @empty.each(&:wakeup)
        @full.each(&:wakeup)
        sleep 0.1
      end
    end
  end
end