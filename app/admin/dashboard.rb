ActiveAdmin.register_page "Dashboard" do

  menu priority: 1, label: proc{ I18n.t("active_admin.dashboard") }

  content title: proc{ I18n.t("active_admin.dashboard") } do


    # Here is an example of a simple dashboard with columns and panels.
    #
    # columns do
    #   column do
    #     panel "Recent Posts" do
    #       ul do
    #         Post.recent(5).map do |post|
    #           li link_to(post.title, admin_post_path(post))
    #         end
    #       end
    #     end
    #   end

    #   column do
    #     panel "Info" do
    #       para "Welcome to ActiveAdmin."
    #     end
    #   end
    # end

    columns do
      column do
        panel 'Chat Statistics' do
          table_for Chat.all do
            column('Chat Title') { |c| link_to(c.display_name, admin_chat_path(c)) }
            column('Members') { |c| c.members.count }
            column('Quotes') { |c| c.quotes.count }
            column('Photos') { |c| c.photos.count }
          end
        end
      end

      column do
        panel 'Unregistered Alexa Devices' do
          table_for Alexa.where chat_id: nil do
            column('Device ID', :device_user) { |u| link_to(u.device_user.truncate(10), admin_alexa_path(u)) }
            column 'Added On', :created_at
          end
        end
      end
    end
  end # content
end
