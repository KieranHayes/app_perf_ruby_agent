require 'active_support/notifications'

module AppPerfRubyAgent
  class NestedEvent < ActiveSupport::Notifications::Event
    attr_reader :action, :category

    def self.arrange(events, options={})
      events.sort! { |a, b| a.end <=> b.end } unless options[:presort] == false

      while event = events.shift
        if parent = events.find { |n| n.parent_of?(event) }
          parent.children << event
        elsif events.empty?
          root = event
        end
      end

      root
    end

    def initialize(*args)
      super
      @action, @category = name.split('.')
      @sample = true
    end

    def duration=(d)
      @duration = d
    end

    def exclusive_duration
      @exclusive_duration ||= duration - children.inject(0.0) { |sum, child| sum + child.duration }
    end

    def gc_duration
      @gc_duration ||= 0
    end

    def sample
      @sample
    end

    def sample=(s)
      @sample = s
    end

    def timestamp
      self.time
    end

    def ended_at
      self.end
    end

    def children
      @children ||= []
    end

    def parent_of?(event)
      start = (timestamp - event.timestamp) * 1000.0
      start <= 0 && (start + duration >= event.duration)
    end

    def child_of?(event)
      event.parent_of?(self)
    end

    def to_hash
      h = {
        :name => name,
        :action => action,
        :category => category,
        :timestamp => timestamp,
        :transaction_id => transaction_id,
        :payload => payload,
        :duration => duration,
        :exclusive_duration => exclusive_duration,
        :end_point => payload[:end_point]
      }
      h.merge!(:children => children.map(&:to_hash)) if children.length > 0
      h
    end
  end
end
