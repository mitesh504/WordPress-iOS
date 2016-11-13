import Foundation


extension NSAttributedString
{
    /// Checks if a given Push Notification is a Push Authentication.
    /// This method will embed a collection of assets, in the specified NSRange's.
    /// Since NSRange is an ObjC struct, you'll need to wrap it up into a NSValue instance!
    ///
    /// - Parameter embeds: A collection of embeds. NSRange > UIImage.
    ///
    /// - Returns: An attributed string with all of the embeds specified, inlined.
    ///
    func stringByEmbeddingImageAttachments(embeds: [NSValue: UIImage]?) -> NSAttributedString {
        // Allow nil embeds: behave as a simple NO-OP
        if embeds == nil {
            return self
        }

        // Proceed embedding!
        let unwrappedEmbeds = embeds!
        let theString       = self.mutableCopy() as! NSMutableAttributedString
        var rangeDelta      = 0

        for (value, image) in unwrappedEmbeds {
            let imageAttachment     = NSTextAttachment()
            imageAttachment.bounds  = CGRect(origin: CGPointZero, size: image.size)
            imageAttachment.image   = image

            // Each embed is expected to add 1 char to the string. Compensate for that
            let attachmentString    = NSAttributedString(attachment: imageAttachment)
            var correctedRange      = value.rangeValue
            correctedRange.location += rangeDelta

            // Bounds Safety
            let lastPosition        = correctedRange.location + correctedRange.length
            if lastPosition <= theString.length {
                theString.replaceCharactersInRange(correctedRange, withAttributedString: attachmentString)
            }

            rangeDelta += attachmentString.length

        }

        return theString
    }

    /// This helper method returns a new NSAttributedString instance, with all of the the leading / trailing newLines
    /// characters removed.
    ///
    func trimNewlines() -> NSAttributedString {
        guard let trimmed = mutableCopy() as? NSMutableAttributedString else {
            return self
        }

        let characterSet = NSCharacterSet.newlineCharacterSet()

        // Trim: Leading
        var range = (trimmed.string as NSString).rangeOfCharacterFromSet(characterSet)

        while range.length != 0 && range.location == 0 {
            trimmed.replaceCharactersInRange(range, withString: String())
            range = (trimmed.string as NSString).rangeOfCharacterFromSet(characterSet)
        }

        // Trim Trailing
        range = (trimmed.string as NSString).rangeOfCharacterFromSet(characterSet, options: .BackwardsSearch)

        while range.length != 0 && NSMaxRange(range) == trimmed.length {
            trimmed.replaceCharactersInRange(range, withString: String())
            range = (trimmed.string as NSString).rangeOfCharacterFromSet(characterSet, options: .BackwardsSearch)
        }

        return trimmed
    }
}
