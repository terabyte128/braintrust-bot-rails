module ApplicationHelpers
  # Build an HTML-formatted quote to display to the user
  def format_quote(content, author, context, date)
    quote = "\"<i>#{content}</i>\"\n<b> - #{author} #{date}</b>"
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

    return "<b>#{formatted}</b>" if bold else formatted
  end

  # Given a list of usernames, remove leading @s, remove duplicates, sort and downcase them
  def process_users(user_names)
    # remove leading @ and downcase
    user_names = user_names.map { |u| if u.start_with? '@' then u[1..-1].downcase else u.downcase end }

    # filter out blank users
    user_names = user_names.select { |u| !u.blank? }

    # remove duplicates
    user_names.uniq.sort
  end
end