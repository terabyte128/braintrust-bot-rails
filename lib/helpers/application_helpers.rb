module ApplicationHelpers
  # Build an HTML-formatted quote to display to the user
  def format_quote(content, author, context, date)
    quote = "\"<i>#{content}</i>\"\n<b> - #{author} #{date}</b>"
    if context
      quote << " (#{context})"
    end
    quote
  end
end