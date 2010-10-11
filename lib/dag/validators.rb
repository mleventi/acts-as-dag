module Dag

    #Validations on model instance creation. Ensures no duplicate links, no cycles, and correct count and direct attributes
  class CreateCorrectnessValidator < ActiveModel::Validator

    def validate(record)
      record.errors[:base] << 'Link already exists between these points' if has_duplicates(record)
      record.errors[:base] << 'Link already exists in the opposite direction' if has_long_cycles(record)
      record.errors[:base] << 'Link must start and end in different places' if has_short_cycles(record)
      cnt = check_possible(record)
      record.errors[:base] << 'Cannot create a direct link with a count other than 0' if cnt == 1
      record.errors[:base] << 'Cannot create an indirect link with a count less than 1' if cnt == 2
    end

    private

    #check for duplicates
    def has_duplicates(record)
      record.class.find_link(record.source, record.sink)
    end

    #check for long cycles
    def has_long_cycles(record)
      record.class.find_link(record.sink, record.source)
    end

    #check for short cycles
    def has_short_cycles(record)
      record.sink.matches?(record.source)
    end

    #check not impossible
    def check_possible(record)
      record.direct? ? (record.count != 0 ? 1 : 0) : (record.count < 1 ? 2 : 0)
    end
  end

  #Validations on update. Makes sure that something changed, that not making a lonely link indirect, and count is correct.
  class UpdateCorrectnessValidator < ActiveModel::Validator

    def validate(record)
      record.errors[:base] << "No changes" unless record.changed?
      record.errors[:base] << "Do not manually change the count value" if manual_change(record)
      record.errors[:base] << "Cannot make a direct link with count 1 indirect" if direct_indirect(record)
    end

    private

    def manual_change(record)
      record.direct_changed? && record.count_changed?
    end

    def direct_indirect(record)
      record.direct_changed? && !record.direct? && record.count == 1
    end
  end

end