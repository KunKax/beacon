class AccountProjectBlocksController < ApplicationController

  before_action :authenticate_account!
  before_action :scope_project
  before_action :enforce_permissions

  def index
    @blocks = @project.account_project_blocks.includes(:account)
    @issues = @project.issues
  end

  def create
    @block = @project.account_project_blocks.new(
      account_id: block_params[:account_id],
      reason: block_params[:reason]
    )
    if @block.save
      redirect_to project_account_project_blocks_url(@project)
    else
      flash[:error] = @block.errors.full_messages
      render :new
    end
  end

  def destroy
    account = Account.find(block_params[:account_id])
    @project.account_project_blocks.find_by(account_id: account.id).destroy
    redirect_to project_account_project_blocks_url(@project)
  end

  private

  def enforce_permissions
    render_forbidden && return unless current_account.can_block_account?(@project)
  end

  def block_params
    params.require(:account_project_block).permit(:account_id, :reason)
  end

  def scope_project
    @project = Project.find_by(slug: params[:project_slug])
  end

end