require "test_helper"

class Assistant::Function::ImportBankStatementTest < ActiveSupport::TestCase
  setup do
    @member = users(:family_member)
    @admin = users(:family_admin)
    @pdf_import = imports(:pdf_processed)
    @fn = Assistant::Function::ImportBankStatement.new(@member)
  end

  test "available_accounts does not leak unshared depository accounts to the member (#1803)" do
    unshared = Account.create!(
      family: families(:dylan_family),
      accountable: Depository.new,
      name: "Private Member-Hidden Checking",
      currency: "USD",
      balance: 100,
      owner: @admin,
    )

    result = @fn.call("pdf_import_id" => @pdf_import.id)

    assert_equal false, result[:success]
    assert_equal "account_required", result[:error]
    available_ids = result[:available_accounts].map { |a| a[:id] }
    refute_includes available_ids, unshared.id,
      "Member-scoped tool must not surface unshared family accounts"
  end

  test "refuses to import into a depository the member does not access (#1803)" do
    unshared = Account.create!(
      family: families(:dylan_family),
      accountable: Depository.new,
      name: "Private Member-Hidden Checking 2",
      currency: "USD",
      balance: 100,
      owner: @admin,
    )

    result = @fn.call(
      "pdf_import_id" => @pdf_import.id,
      "account_id" => unshared.id,
    )

    assert_equal false, result[:success]
    assert_equal "account_not_found", result[:error]
  end
end
