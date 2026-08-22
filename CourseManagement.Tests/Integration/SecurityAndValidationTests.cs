using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using CourseManagement.Application.DTOs;
using CourseManagement.Domain.Models;
using CourseManagement.Web.Extensions;
using CourseManagement.Web.ViewModels;
using Xunit;

namespace CourseManagement.Tests.Integration;

public sealed class SecurityAndValidationTests
{
    [Fact]
    public void GetUserId_ReturnsIdentifierFromNameIdentifierClaim()
    {
        var principal = new ClaimsPrincipal(new ClaimsIdentity(
        [new Claim(ClaimTypes.NameIdentifier, "42")],
        "test"));

        Assert.Equal(42, principal.GetUserId());
    }

    [Fact]
    public void GetUserId_RejectsMissingOrInvalidClaim()
    {
        var principal = new ClaimsPrincipal(new ClaimsIdentity([], "test"));

        Assert.Throws<UnauthorizedAccessException>(() => principal.GetUserId());
    }

    [Fact]
    public void IsAdmin_RecognizesAdminRole()
    {
        var principal = new ClaimsPrincipal(new ClaimsIdentity(
        [new Claim(ClaimTypes.Role, "Admin")],
        "test"));

        Assert.True(principal.IsAdmin());
    }

    [Fact]
    public void CourseFilterDto_NormalizesRangeSortAndPaging()
    {
        var filter = new CourseFilterDto
        {
            Q = "  flutter  ",
            MinPrice = 500,
            MaxPrice = 100,
            Sort = "price-low",
            Page = 0,
            PageSize = 999
        };

        var criteria = filter.ToCriteria();

        Assert.Equal("flutter", criteria.Query);
        Assert.Equal(100, criteria.MinPrice);
        Assert.Equal(500, criteria.MaxPrice);
        Assert.Equal(CourseSortBy.PriceLowToHigh, criteria.SortBy);
        Assert.Equal(1, criteria.Page);
        Assert.Equal(24, criteria.PageSize);
    }

    [Fact]
    public void CourseFilterDto_UsesFeaturedForUnknownSortAndClearsNegativePrices()
    {
        var criteria = new CourseFilterDto
        {
            MinPrice = -1,
            MaxPrice = -2,
            Sort = "unsupported"
        }.ToCriteria();

        Assert.Null(criteria.MinPrice);
        Assert.Null(criteria.MaxPrice);
        Assert.Equal(CourseSortBy.Featured, criteria.SortBy);
    }

    [Fact]
    public void ChangePasswordViewModel_RejectsShortOrMismatchedPassword()
    {
        var model = new ChangePasswordViewModel
        {
            CurrentPassword = "CurrentPassword!1",
            NewPassword = "short",
            ConfirmNewPassword = "different"
        };

        var validationResults = new List<ValidationResult>();
        var context = new ValidationContext(model);
        var isValid = Validator.TryValidateObject(model, context, validationResults, validateAllProperties: true);

        Assert.False(isValid);
        Assert.Contains(validationResults, result => result.MemberNames.Contains(nameof(ChangePasswordViewModel.NewPassword)));
        Assert.Contains(validationResults, result => result.MemberNames.Contains(nameof(ChangePasswordViewModel.ConfirmNewPassword)));
    }
}
