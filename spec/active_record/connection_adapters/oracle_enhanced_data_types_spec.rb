# frozen_string_literal: true

describe "OracleEnhancedAdapter date and datetime type detection based on attribute settings" do
  before(:all) do
    ActiveRecord::Base.establish_connection(CONNECTION_PARAMS)
    @conn = ActiveRecord::Base.connection
    @conn.execute "DROP TABLE test_employees" rescue nil
    @conn.execute "DROP SEQUENCE test_employees_seq" rescue nil
    @conn.execute <<-SQL
      CREATE TABLE test_employees (
        employee_id   NUMBER(6,0) PRIMARY KEY,
        first_name    VARCHAR2(20),
        last_name     VARCHAR2(25),
        email         VARCHAR2(25),
        phone_number  VARCHAR2(20),
        hire_date     DATE,
        job_id        NUMBER(6,0),
        salary        NUMBER(8,2),
        commission_pct  NUMBER(2,2),
        manager_id    NUMBER(6,0),
        department_id NUMBER(4,0),
        created_at    DATE,
        updated_at    DATE
      )
    SQL
    @conn.execute <<-SQL
      CREATE SEQUENCE test_employees_seq  MINVALUE 1
        INCREMENT BY 1 START WITH 10040 CACHE 20 NOORDER NOCYCLE
    SQL
  end

  after(:all) do
    @conn.execute "DROP TABLE test_employees"
    @conn.execute "DROP SEQUENCE test_employees_seq"
  end

  describe "/ DATE values from ActiveRecord model" do
    before(:each) do
      class ::TestEmployee < ActiveRecord::Base
        self.primary_key = "employee_id"
      end
    end

    def create_test_employee(params = {})
      @today = params[:today] || Date.new(2008, 8, 19)
      @now = params[:now] || Time.local(2008, 8, 19, 17, 03, 59)
      @employee = TestEmployee.create(
        first_name: "First",
        last_name: "Last",
        hire_date: @today,
        created_at: @now
      )
      @employee.reload
    end

    after(:each) do
      Object.send(:remove_const, "TestEmployee")
      ActiveRecord::Base.clear_cache!
    end

    it "should return Date value from DATE column by default" do
      create_test_employee
      expect(@employee.hire_date.class).to eq(Date)
    end

    it "should return Date value from DATE column with old date value by default" do
      create_test_employee(today: Date.new(1900, 1, 1))
      expect(@employee.hire_date.class).to eq(Date)
    end

    it "should return Time value from DATE column if attribute is set to :datetime" do
      class ::TestEmployee < ActiveRecord::Base
        attribute :hire_date, :datetime
      end
      create_test_employee
      expect(@employee.hire_date.class).to eq(Time)
      # change to current time with hours, minutes and seconds
      @employee.hire_date = @now
      @employee.save!
      @employee.reload
      expect(@employee.hire_date.class).to eq(Time)
      expect(@employee.hire_date).to eq(@now)
    end
  end
end

describe "OracleEnhancedAdapter assign string to :date and :datetime columns" do
  include SchemaSpecHelper

  before(:all) do
    ActiveRecord::Base.establish_connection(CONNECTION_PARAMS)
    @conn = ActiveRecord::Base.connection
    schema_define do
      create_table :test_employees, force: true do |t|
        t.string    :first_name,  limit: 20
        t.string    :last_name,  limit: 25
        t.date      :hire_date
        t.date      :last_login_at
        t.datetime  :last_login_at_ts
      end
    end
    class ::TestEmployee < ActiveRecord::Base
      attribute :last_login_at, :datetime
    end
    @today = Date.new(2008, 6, 28)
    @today_iso = "2008-06-28"
    @today_nls = "28.06.2008"
    @nls_date_format = "%d.%m.%Y"
    @now = Time.local(2008, 6, 28, 13, 34, 33)
    @now_iso = "2008-06-28 13:34:33"
    @now_nls = "28.06.2008 13:34:33"
    @nls_time_format = "%d.%m.%Y %H:%M:%S"
    @now_nls_with_tz = "28.06.2008 13:34:33+05:00"
    @nls_with_tz_time_format = "%d.%m.%Y %H:%M:%S%Z"
    @now_with_tz = Time.parse @now_nls_with_tz
  end

  after(:all) do
    Object.send(:remove_const, "TestEmployee")
    @conn.drop_table :test_employees, if_exists: true
    ActiveRecord::Base.clear_cache!
  end

  after(:each) do
    ActiveRecord::Base.default_timezone = :utc
  end

  it "should assign ISO string to date column" do
    @employee = TestEmployee.create(
      first_name: "First",
      last_name: "Last",
      hire_date: @today_iso
    )
    expect(@employee.hire_date).to eq(@today)
    @employee.reload
    expect(@employee.hire_date).to eq(@today)
  end

  it "should assign NLS string to date column" do
    @employee = TestEmployee.create(
      first_name: "First",
      last_name: "Last",
      hire_date: @today_nls
    )
    expect(@employee.hire_date).to eq(@today)
    @employee.reload
    expect(@employee.hire_date).to eq(@today)
  end

  it "should assign ISO time string to date column" do
    @employee = TestEmployee.create(
      first_name: "First",
      last_name: "Last",
      hire_date: @now_iso
    )
    expect(@employee.hire_date).to eq(@today)
    @employee.reload
    expect(@employee.hire_date).to eq(@today)
  end

  it "should assign NLS time string to date column" do
    @employee = TestEmployee.create(
      first_name: "First",
      last_name: "Last",
      hire_date: @now_nls
    )
    expect(@employee.hire_date).to eq(@today)
    @employee.reload
    expect(@employee.hire_date).to eq(@today)
  end

  it "should assign ISO time string to datetime column" do
    ActiveRecord::Base.default_timezone = :local
    @employee = TestEmployee.create(
      first_name: "First",
      last_name: "Last",
      last_login_at: @now_iso
    )
    expect(@employee.last_login_at).to eq(@now)
    @employee.reload
    expect(@employee.last_login_at).to eq(@now)
  end

  it "should assign NLS time string to datetime column" do
    ActiveRecord::Base.default_timezone = :local
    @employee = TestEmployee.create(
      first_name: "First",
      last_name: "Last",
      last_login_at: @now_nls
    )
    expect(@employee.last_login_at).to eq(@now)
    @employee.reload
    expect(@employee.last_login_at).to eq(@now)
  end

  it "should assign NLS time string with time zone to datetime column" do
    @employee = TestEmployee.create(
      first_name: "First",
      last_name: "Last",
      last_login_at: @now_nls_with_tz
    )
    expect(@employee.last_login_at).to eq(@now_with_tz)
    @employee.reload
    expect(@employee.last_login_at).to eq(@now_with_tz)
  end

  it "should assign ISO date string to datetime column" do
    ActiveRecord::Base.default_timezone = :local
    @employee = TestEmployee.create(
      first_name: "First",
      last_name: "Last",
      last_login_at: @today_iso
    )
    expect(@employee.last_login_at).to eq(@today.to_time)
    @employee.reload
    expect(@employee.last_login_at).to eq(@today.to_time)
  end

  it "should assign NLS date string to datetime column" do
    ActiveRecord::Base.default_timezone = :local
    @employee = TestEmployee.create(
      first_name: "First",
      last_name: "Last",
      last_login_at: @today_nls
    )
    expect(@employee.last_login_at).to eq(@today.to_time)
    @employee.reload
    expect(@employee.last_login_at).to eq(@today.to_time)
  end

end

describe "OracleEnhancedAdapter handling of BLOB columns" do
  include SchemaSpecHelper

  before(:all) do
    ActiveRecord::Base.establish_connection(CONNECTION_PARAMS)
    @conn = ActiveRecord::Base.connection
    schema_define do
      create_table :test_employees, force: true do |t|
        t.string  :first_name, limit: 20
        t.string  :last_name, limit: 25
        t.binary  :binary_data
      end
    end
    class ::TestEmployee < ActiveRecord::Base
    end
    @binary_data = "\0\1\2\3\4\5\6\7\8\9" * 10000
    @binary_data2 = "\1\2\3\4\5\6\7\8\9\0" * 10000
  end

  after(:all) do
    @conn.drop_table :test_employees, if_exists: true
    Object.send(:remove_const, "TestEmployee")
  end

  after(:each) do
    ActiveRecord::Base.clear_cache!
  end

  it "should create record with BLOB data" do
    @employee = TestEmployee.create!(
      first_name: "First",
      last_name: "Last",
      binary_data: @binary_data
    )
    @employee.reload
    expect(@employee.binary_data).to eq(@binary_data)
  end

  it "should update record with BLOB data" do
    @employee = TestEmployee.create!(
      first_name: "First",
      last_name: "Last"
    )
    @employee.reload
    expect(@employee.binary_data).to be_nil
    @employee.binary_data = @binary_data
    @employee.save!
    @employee.reload
    expect(@employee.binary_data).to eq(@binary_data)
  end

  it "should update record with zero-length BLOB data" do
    @employee = TestEmployee.create!(
      first_name: "First",
      last_name: "Last"
    )
    @employee.reload
    expect(@employee.binary_data).to be_nil
    @employee.binary_data = ""
    @employee.save!
    @employee.reload
    expect(@employee.binary_data).to eq("")
  end

  it "should update record that has existing BLOB data with different BLOB data" do
    @employee = TestEmployee.create!(
      first_name: "First",
      last_name: "Last",
      binary_data: @binary_data
    )
    @employee.reload
    @employee.binary_data = @binary_data2
    @employee.save!
    @employee.reload
    expect(@employee.binary_data).to eq(@binary_data2)
  end

  it "should update record that has existing BLOB data with nil" do
    @employee = TestEmployee.create!(
      first_name: "First",
      last_name: "Last",
      binary_data: @binary_data
    )
    @employee.reload
    @employee.binary_data = nil
    @employee.save!
    @employee.reload
    expect(@employee.binary_data).to be_nil
  end

  it "should update record that has existing BLOB data with zero-length BLOB data" do
    @employee = TestEmployee.create!(
      first_name: "First",
      last_name: "Last",
      binary_data: @binary_data
    )
    @employee.reload
    @employee.binary_data = ""
    @employee.save!
    @employee.reload
    expect(@employee.binary_data).to eq("")
  end

  it "should update record that has zero-length BLOB data with non-empty BLOB data" do
    @employee = TestEmployee.create!(
      first_name: "First",
      last_name: "Last",
      binary_data: ""
    )
    @employee.reload
    expect(@employee.binary_data).to eq("")
    @employee.binary_data = @binary_data
    @employee.save!
    @employee.reload
    expect(@employee.binary_data).to eq(@binary_data)
  end
end

describe "OracleEnhancedAdapter handling of BINARY_FLOAT columns" do
  include SchemaSpecHelper

  before(:all) do
    ActiveRecord::Base.establish_connection(CONNECTION_PARAMS)
    @conn = ActiveRecord::Base.connection
    schema_define do
      create_table :test2_employees, force: true do |t|
        t.string  :first_name, limit: 20
        t.string  :last_name, limit: 25
        t.string  :email, limit: 25
        t.string  :phone_number, limit: 25
        t.date    :hire_date
        t.integer :job_id
        t.integer :salary
        t.decimal :commission_pct, scale: 2, precision: 2
        t.float   :hourly_rate
        t.integer :manager_id,  limit: 6
        t.integer :is_manager,  limit: 1
        t.decimal :department_id, scale: 0, precision: 4
        t.timestamps
      end
    end
    class ::Test2Employee < ActiveRecord::Base
    end
  end

  after(:all) do
    Object.send(:remove_const, "Test2Employee")
    @conn.drop_table :test2_employees, if_exists:  true
  end

  it "should set BINARY_FLOAT column type as float" do
    columns = @conn.columns("test2_employees")
    column = columns.detect { |c| c.name == "hourly_rate" }
    expect(column.type).to eq(:float)
  end

  it "should BINARY_FLOAT column type returns an approximate value" do
    employee = Test2Employee.create(hourly_rate: 4.4)

    employee.reload

    expect(employee.hourly_rate).to eq(4.400000095367432)
  end
end
