class StaticPagesController < ApplicationController
  def index
  end

  def statistics
    if params[:chat_id]
      @chat = Chat.find(params[:chat_id])
      if params[:member]
        @member = @chat.members.find(params[:member])
      end
    else
      @chat = nil
    end
  end

  def get_photo
    unless admin_user_signed_in?
      render plain: "401 Unauthorized", status: 401
      return
    end

    db_image = Photo.find(params[:id])

    local_image = Dir.glob(Rails.root.join("telegram_images/#{db_image.chat_id}/#{db_image.id}*")).first

    if local_image.present?
      extension = local_image.partition('.').last
      send_file local_image, type: "image/#{extension}", disposition: :inline
    else
      raise ActionController::RoutingError.new('Photo not found')
    end
  end
end
