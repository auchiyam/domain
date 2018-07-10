module DomainErrors
    class Error < StandardError; end
    class ValueOutOfBoundsError < Error; end
    class InvalidRuleError < Error; end
    class InvalidSignatureError < Error; end
    class NoMethodAddedError < Error; end
    class SignatureViolationError < Error; end
    class NoTranslationError < Error; end
end