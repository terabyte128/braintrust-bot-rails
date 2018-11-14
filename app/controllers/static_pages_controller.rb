class StaticPagesController < ApplicationController
  def index
  end

  def statistics
    if params[:chat_id]
      @chat = Chat.find(params[:chat_id])
      if params[:member]
        @member = @chat.members.find(params[:member])
      end

      slices = Hash.new(0)
      min = 0; max = 90

      @chat.members.each do |m|
        floored = m.luck.floor(-1)
        slices[floored] += 1

        min = floored if min > floored
        max = floored if max < floored
      end

      (min..max).step(10) do |i|
        slices[i] = 0 unless slices.include?(i)
      end

      sorted_slices = slices.to_a.sort {|a, b| a.first <=> b.first }

      @luck_distribution = sorted_slices.map do |k, v|
        ["#{k.to_s} - #{(k + 9).to_s}", v]
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
