#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Util::SUIDManager do
  before :each do
    the_id = 42
    Puppet::Util::SUIDManager.stubs(:convert_xid).returns(the_id)
    Puppet::Util::SUIDManager.stubs(:initgroups)
    @user = stub('user', :uid => the_id, :gid => the_id, :name => 'name')
  end

  describe "#uid" do
    it "should support dynamically generated methods" do
      # NOTE: the way that we are dynamically generating the methods in
      # SUIDManager for the UID/GID calls was causing problems due to the
      # modification of a closure. Should the bug rear itself again, this
      # test will fail.
      Process.expects(:uid).times(2)

      Puppet::Util::SUIDManager.uid
      Puppet::Util::SUIDManager.uid
    end

    it "should allow setting euid/egid" do
      Process.expects(:euid=).with(@user.uid)
      Process.expects(:egid=).with(@user.gid)

      Puppet::Util::SUIDManager.egid = @user.gid
      Puppet::Util::SUIDManager.euid = @user.uid
    end

    # This test really belongs in util_spec.rb, but this doesn't exist yet.
    it "should not be nil", :unless => Puppet.features.microsoft_windows? do
      Puppet::Util.uid(nonrootuser.name).should_not be_nil
    end
  end

  describe "#asuser" do
    it "should set euid/egid when root", :unless => Puppet.features.microsoft_windows? do
      Process.stubs(:uid).returns(0)
      expects_id_set_and_revert @user.uid, @user.gid
      Puppet::Util::SUIDManager.asuser @user.uid, @user.gid do end
    end

    it "should not get or set euid/egid on Windows" do
      Puppet.features.stubs(:microsoft_windows?).returns true
      expects_no_id_set
      Puppet::Util::SUIDManager.asuser @user.uid, @user.gid do end
    end

    it "should not get or set euid/egid when not root" do
      Process.stubs(:uid).returns(1)
      expects_no_id_set
      Puppet::Util::SUIDManager.asuser @user.uid, @user.gid do end
    end
  end

  describe "#system" do
    it "should set euid/egid when root", :unless => Puppet.features.microsoft_windows? do
      Process.stubs(:uid).returns(0)
      set_exit_status!
      expects_id_set_and_revert @user.uid, @user.gid
      Kernel.expects(:system).with('blah')
      Puppet::Util::SUIDManager.system('blah', @user.uid, @user.gid)
    end

    it "should not get or set euid/egid on Windows" do
      Puppet.features.stubs(:microsoft_windows?).returns true
      set_exit_status!
      expects_no_id_set
      Kernel.expects(:system).with('blah')
      Puppet::Util::SUIDManager.system('blah', @user.uid, @user.gid)
    end

    it "should not get or set euid/egid when not root" do
      Process.stubs(:uid).returns(1)
      set_exit_status!
      expects_no_id_set
      Kernel.expects(:system).with('blah')
      Puppet::Util::SUIDManager.system('blah', @user.uid, @user.gid)
    end
  end

  describe "#run_and_capture" do
    it "should capture the output and return process status" do
      if (RUBY_VERSION <=> "1.8.4") < 0
        warn "Cannot run this test on ruby < 1.8.4"
      else
        set_exit_status!
        Puppet::Util.
          expects(:execute).
          with('yay',:combine => true, :failonfail => false, :uid => @user.uid, :gid => @user.gid).
          returns('output')
        output = Puppet::Util::SUIDManager.run_and_capture 'yay', @user.uid, @user.gid

        output.first.should == 'output'
        output.last.should be_an_instance_of Process::Status
      end
    end
  end

  describe "#root?" do
    describe "on POSIX systems", :if => Puppet.features.posix? do
      it "should be root if uid is 0" do
        Process.stubs(:uid).returns(0)

        Puppet::Util::SUIDManager.should be_root
      end

      it "should not be root if uid is not 0" do
        Process.stubs(:uid).returns(1)

        Puppet::Util::SUIDManager.should_not be_root
      end
    end

    describe "on Microsoft Windows", :if => Puppet.features.microsoft_windows? do
      it "should be root if user is a member of the Administrators group" do
        Win32::Security.stubs(:elevated_security?).returns(false)
        Sys::Admin.stubs(:get_login).returns("Administrator")

        Puppet::Util::SUIDManager.should be_root
      end

      it "should be root if the process is running with elevated privileges" do
        Win32::Security.stubs(:elevated_security?).returns(true)
        Sys::Admin.stubs(:get_login).returns("Guest")

        Puppet::Util::SUIDManager.should be_root
      end

      it "should not be root if user is not a member of the Administrators group" do
        Sys::Admin.stubs(:get_login).returns("Guest")

        Puppet::Util::SUIDManager.should_not be_root
      end
    end
  end

  private

  def set_exit_status!
    # We want to make sure $CHILD_STATUS is set, this is the only way I know how.
    Kernel.system '' if $CHILD_STATUS.nil?
  end

  def expects_id_set_and_revert(uid, gid)
    Process.stubs(:groups=)
    Process.expects(:euid).returns(99997)
    Process.expects(:egid).returns(99996)

    Process.expects(:euid=).with(uid)
    Process.expects(:egid=).with(gid)

    Process.expects(:euid=).with(99997)
    Process.expects(:egid=).with(99996)
  end

  def expects_no_id_set
    Process.expects(:egid).never
    Process.expects(:euid).never
    Process.expects(:egid=).never
    Process.expects(:euid=).never
  end

  def nonrootuser
    return Sys::Admin.get_user("Guest") if Puppet.features.microsoft_windows?

    Etc.passwd { |user|
      return user if user.uid != Puppet::Util::SUIDManager.uid and user.uid > 0 and user.uid < 255
    }
  end
end
