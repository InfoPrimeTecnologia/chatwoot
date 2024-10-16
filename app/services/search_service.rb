class SearchService
  pattr_initialize [:current_user!, :current_account!, :params!, :search_type!]

  def perform
    case search_type
    when 'Message'
      { messages: filter_messages }
    when 'Conversation'
      { conversations: filter_conversations }
    when 'Contact'
      { contacts: filter_contacts }
    else
      { contacts: filter_contacts, messages: filter_messages, conversations: filter_conversations }
    end
  end

  private

  def accessable_inbox_ids
    @accessable_inbox_ids ||= @current_user.assigned_inboxes.pluck(:id)
  end

  def search_query
    @search_query ||= params[:q].to_s.strip
  end

  def filter_conversations
    @conversations = current_account.conversations.where(inbox_id: accessable_inbox_ids)
  
    unless Current.account_user.administrator?
      participant_conversation_ids = ConversationParticipant.where(user_id: current_user.id).select(:conversation_id)
      @conversations = @conversations.where(
        'conversations.assignee_id = :user_id OR conversations.id IN (:conversation_ids)',
        user_id: current_user.id,
        conversation_ids: participant_conversation_ids
      )
    end
  
    @conversations = @conversations
                     .joins('INNER JOIN contacts ON conversations.contact_id = contacts.id')
                     .where(
                       "CAST(conversations.display_id AS TEXT) ILIKE :search OR contacts.name ILIKE :search OR contacts.email ILIKE :search OR contacts.phone_number ILIKE :search OR contacts.identifier ILIKE :search",
                       search: "%#{search_query}%"
                     )
                     .order('conversations.created_at DESC')
                     .limit(10)
  end
  

  def filter_messages
    @messages = current_account.messages.where(inbox_id: accessable_inbox_ids)
  
    unless Current.account_user.administrator?
      participant_conversation_ids = ConversationParticipant.where(user_id: current_user.id).pluck(:conversation_id)
  
      participant_assigned_conversation_ids = Conversation.where(
        assignee_id: current_user.id,
        id: participant_conversation_ids
      ).pluck(:id)
  
      agent_messages = @messages.where(sender_id: current_user.id, sender_type: 'User')
  
      participant_assigned_messages = @messages.where(conversation_id: participant_assigned_conversation_ids)
  
      contact_messages_in_participant_conversations = @messages.where(
        conversation_id: participant_conversation_ids,
        sender_type: 'Contact'
      )
  
      # Combinar todas as mensagens
      @messages = agent_messages
                    .or(participant_assigned_messages)
                    .or(contact_messages_in_participant_conversations)
    end
  
    @messages = @messages
                  .where('messages.content ILIKE :search', search: "%#{search_query}%")
                  .where('messages.created_at >= ?', 3.months.ago)
                  .reorder('messages.created_at DESC')
                  .limit(10)
  end
  

  def filter_contacts
    @contacts = current_account.contacts.where(
      "name ILIKE :search OR email ILIKE :search OR phone_number
      ILIKE :search OR identifier ILIKE :search", search: "%#{search_query}%"
    ).resolved_contacts.order_on_last_activity_at('desc').limit(10)
  end
end