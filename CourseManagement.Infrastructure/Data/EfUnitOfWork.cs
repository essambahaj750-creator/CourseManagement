using CourseManagement.Application.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace CourseManagement.Infrastructure.Data;

public sealed class EfUnitOfWork(ApplicationDbContext context) : IUnitOfWork
{
    public async Task<IUnitOfWorkTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default) =>
        new EfUnitOfWorkTransaction(await context.Database.BeginTransactionAsync(cancellationToken));

    private sealed class EfUnitOfWorkTransaction(IDbContextTransaction transaction) : IUnitOfWorkTransaction
    {
        public Task CommitAsync(CancellationToken cancellationToken = default) =>
            transaction.CommitAsync(cancellationToken);

        public ValueTask DisposeAsync() => transaction.DisposeAsync();
    }
}
