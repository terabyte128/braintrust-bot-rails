module ApplicationHelpers
  # Build an HTML-formatted quote to display to the user
  def format_quote(content, author, context, date)
    quote = "\"<i>#{content.capitalize}</i>\"\n<b> - #{author.titleize} #{date}</b>"
    if context.present?
      quote << " (#{context})"
    end
    quote
  end

  # try first last, then first, then username
  def pretty_name(user, bold=false)
    if user.first_name.present?
      if user.last_name.present?
        formatted = "#{user.first_name} #{user.last_name}"
      else
        formatted = user.first_name
      end
    else
      formatted = user.username
    end

    if bold
      "<b>#{formatted}</b>"
    else
      formatted
    end
  end
end