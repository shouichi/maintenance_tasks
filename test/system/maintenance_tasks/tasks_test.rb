# frozen_string_literal: true

require "application_system_test_case"

module MaintenanceTasks
  class TasksTest < ApplicationSystemTestCase
    test "list all tasks" do
      visit maintenance_tasks_path

      assert_title "Maintenance Tasks"

      assert_link "Maintenance::UpdatePostsTask"
      assert_link "Maintenance::ErrorTask"
    end

    test "lists tasks by category" do
      visit maintenance_tasks_path

      expected = [
        "New Tasks",
        "Maintenance::CancelledEnqueueTask\nNew",
        "Maintenance::EnqueueErrorTask\nNew",
        "Maintenance::ErrorTask\nNew",
        "Maintenance::ImportPostsTask\nNew",
        "Maintenance::ParamsTask\nNew",
        "Maintenance::TestTask\nNew",
        "Maintenance::UpdatePostsInBatchesTask\nNew",
        "Maintenance::UpdatePostsThrottledTask\nNew",
        "Completed Tasks",
        "Maintenance::UpdatePostsTask\nSucceeded",
      ]

      assert_equal expected, page.all("h3").map(&:text)
    end

    test "show a Task" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsTask")

      assert_title "Maintenance::UpdatePostsTask"
      assert_text "Succeeded"
      assert_text "Ran for less than 5 seconds, finished 8 days ago."
    end

    test "view a Task with multiple pages of Runs" do
      Run.create!(
        task_name: "Maintenance::TestTask",
        created_at: 1.hour.ago,
        started_at: 1.hour.ago,
        tick_count: 2,
        tick_total: 10,
        status: :errored,
        ended_at: 1.hour.ago
      )
      21.times do |i|
        Run.create!(
          task_name: "Maintenance::TestTask",
          created_at: i.minutes.ago,
          started_at: i.minutes.ago,
          tick_count: 10,
          tick_total: 10,
          status: :succeeded,
          ended_at: i.minutes.ago
        )
      end

      visit maintenance_tasks_path

      click_on("Maintenance::TestTask")
      assert_no_text "Errored"

      click_on("Next page")
      assert_text "Errored"
      assert_no_link "Next page"
    end

    test "show a deleted Task" do
      visit maintenance_tasks_path + "/tasks/Maintenance::DeletedTask"

      assert_title "Maintenance::DeletedTask"
      assert_text "Succeeded"
      assert_button "Run", disabled: true
    end

    test "visit main page through iframe" do
      visit root_path

      within_frame("maintenance-tasks-iframe") do
        assert_content "Maintenance Tasks"
      end
    end
  end
end
