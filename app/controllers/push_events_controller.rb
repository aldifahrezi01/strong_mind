class PushEventsController < ApplicationController
  def index
    events = PushEvent.recent.limit(limit_param).includes(:github_actor, :github_repository)
    render json: events.map { |event| serialize(event) }
  end

  def show
    event = PushEvent.includes(:github_actor, :github_repository).find_by!(github_event_id: params[:id])
    render json: serialize(event, include_raw: true)
  end

  private

  def limit_param
    [params.fetch(:limit, 20).to_i, 100].min
  end

  def serialize(event, include_raw: false)
    data = {
      id: event.id,
      github_event_id: event.github_event_id,
      repository_github_id: event.repository_github_id,
      push_id: event.push_id,
      ref: event.ref,
      head: event.head,
      before: event.before,
      enrichment_status: event.enrichment_status,
      github_created_at: event.github_created_at,
      actor: event.github_actor && {
        login: event.github_actor.login,
        github_id: event.github_actor.github_id
      },
      repository: event.github_repository && {
        full_name: event.github_repository.full_name,
        github_id: event.github_repository.github_id
      }
    }
    data[:raw_payload] = event.raw_payload if include_raw
    data
  end
end
