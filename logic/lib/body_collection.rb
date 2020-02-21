class BodyCollection

  extend Forwardable
  include Enumerable

  def_delegators :@bodies, :length, :size

  def initialize
    @bodies = {}
  end

  def each
    @bodies.values.each do |v|
      yield v
    end
  end

  def << body
    @bodies[body.uuid] = body
  end

  def get uuid
    @bodies[uuid]
  end

  def include? body
    !@bodies[body.uuid].nil?
  end

  def delete body
    @bodies.delete body.uuid
  end

  def near target_location
    raise ArgumentError if target_location.nil?
    sort_by do |body|
      body.distance_to target_location
    end.first
  end

  def nearby target_location, max_distance: 10
    raise ArgumentError if target_location.nil?
    self
      .sort_by    { |b| b.distance_to(target_location) }
      .take_while { |b| b.distance_to(target_location) < max_distance }
  end
end

class BodyCollectionLookup
  include Enumerable

  attr_accessor :collections

  def initialize
    self.collections = {}
  end

  def add_body body: nil, type: nil
    collection(type: type) << body
  end

  def remove_body body: nil
    self.collections.values.each do |collection|
      collection.delete body
    end
  end

  def collection type: nil
    self.collections[type] ||= BodyCollection.new
  end

  def get uuid: nil
    collections.values.each do |collection|
      body = collection.get uuid
      if body
        return body
      end
    end
    return nil
  end

  def each
    @collections.values.map(&:to_a).flatten.uniq.each do |body|
      yield body
    end
  end

  def to_h
    r = {}
    each do |b|
      r[b.uuid] = b
    end
    r
  end
end

