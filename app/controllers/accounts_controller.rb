class AccountsController < ApplicationController
  before_action :set_account, only: %i[edit update destroy]

  def new
    @account = Account.new
  end

  def create
    @account = Account.new(account_params)

    if @account.save
      redirect_to root_path, notice: "Account added 🎉"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to root_path, notice: "Account updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @account.name
    @account.destroy!
    redirect_to root_path, notice: "Removed #{name}"
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :institution, :kind)
  end
end
