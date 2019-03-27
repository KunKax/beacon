class RespondentTemplatesController < ApplicationController

  before_action :authenticate_account!
  before_action :scope_project
  before_action :scope_organization
  before_action :enforce_permissions
  before_action :scope_available_templates, except: [:update]

  def new
    if organization = @organization || @project.organization
      breadcrumb "Organizations", organizations_path
      breadcrumb organization.name, organization_path(organization)
      breadcrumb(@project.name, project_path(@project)) if @project
    else
      breadcrumb "Projects", projects_path if @project
      breadcrumb(@project.name, project_path(@project))
    end
    if @project
      @template = RespondentTemplate.new(project_id: @project.id)
    else
      @template = RespondentTemplate.new(organization_id: @organization.id)
    end
  end

  def create
    if @project
      @template = RespondentTemplate.new(respondent_template_params.merge(project_id: @project.id))
    elsif @organization
      @template = RespondentTemplate.new(respondent_template_params.merge(organization_id: @organization.id))
    end
    if @template.save
      redirect_to project_path(@project) if @project
      redirect_to organization_path(@organization) if @organization
    else
      flash[:error] = @template.errors.full_messages
      render :new
    end
  end

  def clone
    if @organization
      breadcrumb "Organizations", organizations_path
      breadcrumb @organization.name, organization_path(@organization)
    else
      breadcrumb "Projects", projects_path
    end
    breadcrumb @project.name, project_path(@project)
    if existing = @subject.respondent_template
      existing.destroy
    end
    source = respondent_template_params[:respondent_template_default_source]
    if source == "Beacon Default"
      @template = @subject.create_respondent_template(text: RespondentTemplate.beacon_default.text)
    elsif source == "Organization Default"
      @template = @subject.create_respondent_template(text: @organization&.respondent_template&.text || @project.organization&.respondent_template.text)
    else
      source = current_account.projects.find_by(name: source).respondent_template
      @template = @subject.create_respondent_template(text: source.text)
    end
    flash[:notice] = "You have successfully updated the respondent template."
    render :edit
  end

  def edit
    if organization = @organization || @project.organization
      breadcrumb "Organizations", organizations_path
      breadcrumb organization.name, organization_path(organization)
      breadcrumb(@project.name, project_path(@project)) if @project
    else
      breadcrumb "Projects", projects_path if @project
      breadcrumb(@project.name, project_path(@project))
    end
    @template = @subject.respondent_template
  end

  def update
    @template = @subject.respondent_template
    if @template.update_attributes(respondent_template_params)
      redirect_to @subject
    else
      flash[:error] = @template.errors.full_messages
    end
  end

  private

  def enforce_permissions
    render_forbidden && return if @project && !current_account.can_manage_project_respondent_template?(@project)
    render_forbidden && return if @organization && !current_account.can_manage_organization?(@organization)
  end

  def respondent_template_params
    params.require(:respondent_template).permit(:text, :respondent_template_default_source)
  end

  def scope_available_templates
    if @project&.organization
      projects_with_respondent_template = @project.organization.projects.select(&:respondent_template?).map(&:name)
    elsif @organization
      projects_with_respondent_template = @organization.projects.select(&:respondent_template?).map(&:name)
    end
    projects_with_respondent_template ||= current_account.personal_projects.select(&:respondent_template?).map(&:name)
    if @project
      org_template = @project.organization.present? && @project.organization.respondent_template? ? "Organization Default" : nil
    else
      org_template = "Organization Default"
    end
    @available_templates = ["Beacon Default", org_template, projects_with_respondent_template].flatten.compact - [@project&.name]
  end

  def scope_organization
    @organization = Organization.find_by(slug: params[:organization_slug])
    @organization ||= @project.organization
    @subject ||= @organization
  end

  def scope_project
    @project = Project.find_by(slug: params[:project_slug])
    @subject = @project
  end

end
