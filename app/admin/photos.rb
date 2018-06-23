ActiveAdmin.register Photo do
# See permitted parameters documentation:
# https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
#
# permit_params :list, :of, :attributes, :on, :model
#
# or
#
# permit_params do
#   permitted = [:permitted, :attributes]
#   permitted << :other if params[:action] == 'create' && current_user.admin?
#   permitted
# end

  show do
    attributes_table do
      row :chat
      row :member
      row :caption

      row('Image') do |pic|
        image_tag get_photo_path(pic.id)
      end
    end
    active_admin_comments
  end

  index do
    selectable_column
    column(:id, sortable: :id) { |p| link_to(p.id, admin_photo_path(p)) }
    column :caption, sortable: :caption
    column :chat, sortable: :chat_id
    column :member, sortable: :member_id
  end

  permit_params :chat_id, :member_id, :caption, :telegram_photo
end

