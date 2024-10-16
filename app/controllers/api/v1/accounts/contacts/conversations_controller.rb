class Api::V1::Accounts::Contacts::ConversationsController < Api::V1::Accounts::Contacts::BaseController
  def index
    @conversations = @contact.conversations.where(account_id: current_account.id)

    unless Current.user.administrator?
      @conversations = @conversations.accessible_by_user(Current.user)
    end

  end

  private

  def inbox_ids
    if Current.user.administrator? || Current.user.agent?
      Current.user.assigned_inboxes.pluck(:id)
    else
      []
    end
  end
end
